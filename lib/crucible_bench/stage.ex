defmodule CrucibleBench.Stage do
  @moduledoc """
  Pipeline stage for statistical benchmarking.

  Implements the Crucible.Stage behaviour for use in crucible_framework pipelines.
  Uses CrucibleIR.Reliability.Stats configuration for test selection and parameters.

  ## Context Requirements

  The context map must contain:
  - `experiment.reliability.stats` - CrucibleIR.Reliability.Stats configuration

  And one of the following data layouts:
  - `outputs` or `metrics` - Single group data (list of numeric values)
  - `control` and `treatment` - Two independent groups for t-test, Mann-Whitney
  - `groups` - List of groups for ANOVA, Kruskal-Wallis
  - `before` and `after` - Paired data for paired t-test, Wilcoxon

  ## Returns

  Updated context with:
  - `:bench` key containing detailed statistical analysis results
  - `:metrics` key merged with summary statistics and p-values

  ## Example

      # Two-group comparison
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest],
              alpha: 0.05
            }
          }
        },
        control: [0.72, 0.68, 0.75, 0.71, 0.69],
        treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
      }

      {:ok, updated_context} = CrucibleBench.Stage.run(context)
      # updated_context.bench contains test results
      # updated_context.metrics contains bench_ttest_p_value, etc.
  """

  alias CrucibleBench.Stats

  # Conditionally use behaviour if crucible_framework is available
  if Code.ensure_loaded?(Crucible.Stage) do
    @behaviour Crucible.Stage
  end

  @type context :: map()
  @type opts :: map()
  @type error_reason :: String.t()

  @type data_type ::
          {:single, [number()]}
          | {:paired, [number()], [number()]}
          | {:two_groups, [number()], [number()]}
          | {:multiple_groups, [[number()]]}

  @doc """
  Runs statistical analysis on experiment outputs.

  Accepts a context map with experiment configuration and data. Extracts the
  statistical configuration from `experiment.reliability.stats` and runs the
  specified tests on the provided data.

  ## Options

  Options can be provided to override IR config:
  - `:tests` - List of tests to run (overrides config)
  - `:alpha` - Significance level (overrides config)
  - `:confidence_level` - Confidence level (overrides config)
  - `:data_key` - Key to extract data from context (default: `:outputs`)

  ## Returns

  - `{:ok, context}` - Updated context with bench results and merged metrics
  - `{:error, reason}` - If configuration or data is missing/invalid
  """
  @spec run(context(), opts()) :: {:ok, context()} | {:error, error_reason()}
  def run(context, opts \\ %{}) when is_map(context) do
    with {:ok, stats_config} <- extract_stats_config(context),
         {:ok, data} <- extract_data(context, opts),
         {:ok, results} <- run_tests(data, stats_config, opts) do
      # Extract key metrics for pipeline
      bench_metrics = %{
        bench_n: results.summary.n,
        bench_mean: results.summary.mean,
        bench_sd: results.summary.sd,
        bench_median: results.summary.median
      }

      # Add test-specific metrics (p-values)
      bench_metrics =
        Enum.reduce(results.tests, bench_metrics, fn {test_name, test_result}, acc ->
          if is_map(test_result) and Map.has_key?(test_result, :p_value) do
            Map.put(acc, :"bench_#{test_name}_p_value", test_result.p_value)
          else
            acc
          end
        end)

      # Merge into existing metrics (only if it's a map, otherwise start fresh)
      existing_metrics =
        case Map.get(context, :metrics) do
          m when is_map(m) -> m
          _ -> %{}
        end

      updated_metrics = Map.merge(existing_metrics, bench_metrics)

      context
      |> Map.put(:bench, results)
      |> Map.put(:metrics, updated_metrics)
      |> then(&{:ok, &1})
    end
  end

  @doc """
  Describes this stage for introspection.

  Returns metadata about the stage including its purpose, requirements, and
  configuration options.

  ## Options

  - `:verbose` - Include detailed information (default: false)
  """
  @spec describe(opts()) :: map()
  def describe(opts \\ %{}) do
    verbose = Map.get(opts, :verbose, false)

    base = %{
      name: "CrucibleBench.Stage",
      type: :analysis,
      purpose: "Statistical testing and analysis",
      inputs: [:outputs, :metrics, :control, :treatment, :groups, :before, :after],
      outputs: [:bench, :metrics],
      config_source: "experiment.reliability.stats"
    }

    if verbose do
      Map.merge(base, %{
        available_tests: [:ttest, :bootstrap, :anova, :mannwhitney, :wilcoxon, :kruskal],
        effect_sizes: [:cohens_d, :eta_squared, :omega_squared],
        corrections: [:bonferroni, :holm, :benjamini_hochberg],
        requirements: [
          "CrucibleIR.Reliability.Stats configuration",
          "Numeric data in one of the supported layouts"
        ],
        data_layouts: [
          "Single group: :outputs or :metrics",
          "Two groups: :control and :treatment",
          "Multiple groups: :groups",
          "Paired: :before and :after"
        ]
      })
    else
      base
    end
  end

  # Private Functions

  @spec extract_stats_config(context()) ::
          {:ok, CrucibleIR.Reliability.Stats.t()} | {:error, error_reason()}
  defp extract_stats_config(context) do
    case get_in(context, [:experiment, :reliability, :stats]) do
      %CrucibleIR.Reliability.Stats{} = config ->
        {:ok, config}

      nil ->
        {:error, "Missing experiment.reliability.stats configuration"}

      other ->
        {:error, "Invalid stats config: #{inspect(other)}"}
    end
  end

  @spec extract_data(context(), opts()) :: {:ok, data_type()} | {:error, error_reason()}
  defp extract_data(context, opts) do
    cond do
      # Check for paired data (before/after)
      Map.has_key?(context, :before) and Map.has_key?(context, :after) ->
        with {:ok, before} <- validate_numeric_list(context.before, "before"),
             {:ok, after_data} <- validate_numeric_list(context.after, "after") do
          {:ok, {:paired, before, after_data}}
        end

      # Check for two-group data (control/treatment)
      Map.has_key?(context, :control) and Map.has_key?(context, :treatment) ->
        with {:ok, control} <- validate_numeric_list(context.control, "control"),
             {:ok, treatment} <- validate_numeric_list(context.treatment, "treatment") do
          {:ok, {:two_groups, control, treatment}}
        end

      # Check for multiple groups
      Map.has_key?(context, :groups) ->
        case validate_groups(context.groups) do
          {:ok, groups} -> {:ok, {:multiple_groups, groups}}
          error -> error
        end

      # Fall back to single group data (original behavior)
      true ->
        extract_single_group_data(context, opts)
    end
  end

  defp extract_single_group_data(context, opts) do
    data_key = Map.get(opts, :data_key, :outputs)

    case Map.get(context, data_key) do
      nil ->
        # Try alternative key
        case Map.get(context, :metrics) do
          nil -> {:error, "No data found in context (tried #{data_key} and :metrics)"}
          data -> validate_and_wrap_single(data)
        end

      data ->
        validate_and_wrap_single(data)
    end
  end

  defp validate_and_wrap_single(data) when is_list(data) do
    if Enum.all?(data, &is_number/1) do
      {:ok, {:single, data}}
    else
      # Try extracting numeric values from maps
      extract_numeric_values(data)
    end
  end

  defp validate_and_wrap_single(_), do: {:error, "Data must be a list"}

  defp validate_numeric_list(data, name) when is_list(data) do
    if Enum.all?(data, &is_number/1) do
      {:ok, data}
    else
      {:error, "#{name} must contain only numeric values"}
    end
  end

  defp validate_numeric_list(_, name), do: {:error, "#{name} must be a list"}

  defp validate_groups(groups) when is_list(groups) do
    validated =
      Enum.map(groups, fn group ->
        if is_list(group) and Enum.all?(group, &is_number/1) do
          {:ok, group}
        else
          {:error, "Each group must be a list of numbers"}
        end
      end)

    case Enum.find(validated, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(validated, fn {:ok, g} -> g end)}
      error -> error
    end
  end

  defp validate_groups(_), do: {:error, "groups must be a list of lists"}

  defp extract_numeric_values(data) do
    case Enum.all?(data, &is_map/1) do
      true ->
        # Try to find a numeric field
        first = List.first(data)
        numeric_keys = for {k, v} <- first, is_number(v), do: k

        if Enum.empty?(numeric_keys) do
          {:error, "No numeric values found in data"}
        else
          # Use first numeric key
          key = List.first(numeric_keys)
          values = Enum.map(data, & &1[key])
          {:ok, {:single, values}}
        end

      false ->
        {:error, "Data must be list of numbers or maps with numeric values"}
    end
  end

  defp run_tests(data, config, opts) do
    # Build test options from config and opts
    test_opts = build_test_opts(config, opts)

    # Determine which tests to run
    tests_to_run = Map.get(opts, :tests) || config.tests || [:ttest]

    # Build summary based on data type
    summary = build_summary(data)

    # Run tests
    results = %{
      tests: %{},
      config: %{
        alpha: test_opts[:alpha],
        confidence_level: test_opts[:confidence_level],
        tests_requested: tests_to_run
      },
      summary: summary,
      data_type: data_type_name(data)
    }

    # Execute each test type
    results =
      Enum.reduce(tests_to_run, results, fn test, acc ->
        case execute_test(test, data, test_opts) do
          {:ok, test_result} ->
            put_in(acc, [:tests, test], test_result)

          {:error, reason} ->
            put_in(acc, [:tests, test], %{error: reason})
        end
      end)

    {:ok, results}
  end

  defp data_type_name({:single, _}), do: :single
  defp data_type_name({:paired, _, _}), do: :paired
  defp data_type_name({:two_groups, _, _}), do: :two_groups
  defp data_type_name({:multiple_groups, _}), do: :multiple_groups

  defp build_summary({:single, data}) do
    %{
      n: length(data),
      mean: Stats.mean(data),
      sd: Stats.stdev(data),
      median: Stats.median(data)
    }
  end

  defp build_summary({:paired, before, after_data}) do
    all_data = before ++ after_data

    %{
      n: length(before),
      mean: Stats.mean(all_data),
      sd: Stats.stdev(all_data),
      median: Stats.median(all_data),
      before_mean: Stats.mean(before),
      after_mean: Stats.mean(after_data)
    }
  end

  defp build_summary({:two_groups, group1, group2}) do
    all_data = group1 ++ group2

    %{
      n: length(group1) + length(group2),
      mean: Stats.mean(all_data),
      sd: Stats.stdev(all_data),
      median: Stats.median(all_data),
      control_n: length(group1),
      treatment_n: length(group2),
      control_mean: Stats.mean(group1),
      treatment_mean: Stats.mean(group2)
    }
  end

  defp build_summary({:multiple_groups, groups}) do
    all_data = List.flatten(groups)

    %{
      n: length(all_data),
      mean: Stats.mean(all_data),
      sd: Stats.stdev(all_data),
      median: Stats.median(all_data),
      k: length(groups),
      group_sizes: Enum.map(groups, &length/1),
      group_means: Enum.map(groups, &Stats.mean/1)
    }
  end

  defp build_test_opts(config, opts) do
    [
      alpha: Map.get(opts, :alpha) || config.alpha || 0.05,
      confidence_level: Map.get(opts, :confidence_level) || config.confidence_level || 0.95,
      effect_size_type: Map.get(opts, :effect_size_type) || config.effect_size_type,
      multiple_testing_correction:
        Map.get(opts, :multiple_testing_correction) || config.multiple_testing_correction,
      bootstrap_iterations: Map.get(opts, :bootstrap_iterations) || config.bootstrap_iterations,
      options: Map.get(opts, :options) || config.options
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  # All execute_test clauses grouped together to avoid warnings

  # T-Test implementations
  defp execute_test(:ttest, {:two_groups, group1, group2}, opts) do
    alpha = Keyword.get(opts, :alpha, 0.05)
    result = Stats.TTest.test(group1, group2)
    effect = Stats.EffectSize.cohens_d(group1, group2)

    {:ok,
     %{
       test_type: :ttest,
       statistic: result.statistic,
       p_value: result.p_value,
       significant: result.p_value < alpha,
       effect_size: effect,
       confidence_interval: result.confidence_interval,
       interpretation: result.interpretation
     }}
  end

  defp execute_test(:ttest, {:paired, before, after_data}, opts) do
    alpha = Keyword.get(opts, :alpha, 0.05)
    result = Stats.PairedTTest.test(before, after_data)
    effect = Stats.EffectSize.paired_cohens_d(before, after_data)

    {:ok,
     %{
       test_type: :paired_ttest,
       statistic: result.statistic,
       p_value: result.p_value,
       significant: result.p_value < alpha,
       effect_size: effect,
       confidence_interval: result.confidence_interval,
       interpretation: result.interpretation
     }}
  end

  defp execute_test(:ttest, {:single, data}, _opts) do
    {:ok,
     %{
       test_type: :ttest,
       note: "Single group analysis - requires comparison groups for t-test",
       data_summary: %{n: length(data), mean: Stats.mean(data), sd: Stats.stdev(data)}
     }}
  end

  defp execute_test(:ttest, {:multiple_groups, _groups}, _opts) do
    {:error, "t-test requires exactly two groups. Use ANOVA for multiple groups."}
  end

  # Bootstrap implementations
  defp execute_test(:bootstrap, {:single, data}, opts), do: do_bootstrap(data, opts)
  defp execute_test(:bootstrap, {:paired, before, _after}, opts), do: do_bootstrap(before, opts)

  defp execute_test(:bootstrap, {:two_groups, group1, _group2}, opts),
    do: do_bootstrap(group1, opts)

  defp execute_test(:bootstrap, {:multiple_groups, groups}, opts) do
    all_data = List.flatten(groups)
    do_bootstrap(all_data, opts)
  end

  # ANOVA implementations
  defp execute_test(:anova, {:multiple_groups, groups}, opts) do
    alpha = Keyword.get(opts, :alpha, 0.05)
    result = Stats.ANOVA.one_way(groups)

    {:ok,
     %{
       test_type: :anova,
       statistic: result.statistic,
       p_value: result.p_value,
       significant: result.p_value < alpha,
       effect_size: result.effect_size,
       interpretation: result.interpretation,
       metadata: result.metadata
     }}
  end

  defp execute_test(:anova, {:two_groups, group1, group2}, opts) do
    execute_test(:anova, {:multiple_groups, [group1, group2]}, opts)
  end

  defp execute_test(:anova, _data, _opts) do
    {:ok,
     %{
       test_type: :anova,
       note: "Requires multiple groups - not applicable to single or paired data"
     }}
  end

  # Mann-Whitney implementations
  defp execute_test(:mannwhitney, {:two_groups, group1, group2}, opts) do
    alpha = Keyword.get(opts, :alpha, 0.05)
    result = Stats.MannWhitney.test(group1, group2)

    {:ok,
     %{
       test_type: :mannwhitney,
       statistic: result.statistic,
       p_value: result.p_value,
       significant: result.p_value < alpha,
       effect_size: result.effect_size,
       interpretation: result.interpretation
     }}
  end

  defp execute_test(:mannwhitney, _data, _opts) do
    {:ok,
     %{
       test_type: :mannwhitney,
       note: "Requires two independent groups - not applicable to other data layouts"
     }}
  end

  # Wilcoxon implementations
  defp execute_test(:wilcoxon, {:paired, before, after_data}, opts) do
    alpha = Keyword.get(opts, :alpha, 0.05)
    result = Stats.Wilcoxon.test(before, after_data)

    {:ok,
     %{
       test_type: :wilcoxon,
       statistic: result.statistic,
       p_value: result.p_value,
       significant: result.p_value < alpha,
       effect_size: result.effect_size,
       interpretation: result.interpretation
     }}
  end

  defp execute_test(:wilcoxon, _data, _opts) do
    {:ok,
     %{
       test_type: :wilcoxon,
       note: "Requires paired data (:before and :after) - not applicable to other data layouts"
     }}
  end

  # Kruskal-Wallis implementations
  defp execute_test(:kruskal, {:multiple_groups, groups}, opts) do
    alpha = Keyword.get(opts, :alpha, 0.05)
    result = Stats.KruskalWallis.test(groups)

    {:ok,
     %{
       test_type: :kruskal,
       statistic: result.statistic,
       p_value: result.p_value,
       significant: result.p_value < alpha,
       effect_size: result.effect_size,
       interpretation: result.interpretation
     }}
  end

  defp execute_test(:kruskal, {:two_groups, group1, group2}, opts) do
    execute_test(:kruskal, {:multiple_groups, [group1, group2]}, opts)
  end

  defp execute_test(:kruskal, _data, _opts) do
    {:ok,
     %{
       test_type: :kruskal,
       note: "Requires multiple groups - not applicable to single or paired data"
     }}
  end

  # Unknown test type (catch-all)
  defp execute_test(test_type, _data, _opts) do
    {:error, "Unknown test type: #{test_type}"}
  end

  # Helper for bootstrap confidence interval
  defp do_bootstrap(data, opts) do
    iterations = Keyword.get(opts, :bootstrap_iterations, 1000)
    confidence_level = Keyword.get(opts, :confidence_level, 0.95)

    ci =
      Stats.ConfidenceInterval.calculate(data, :mean,
        method: :bootstrap,
        iterations: iterations,
        confidence_level: confidence_level
      )

    {:ok,
     %{
       test_type: :bootstrap,
       confidence_interval: ci.interval,
       method: ci.method,
       iterations: iterations
     }}
  end
end
