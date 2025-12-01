defmodule CrucibleBench.Stage do
  @moduledoc """
  Pipeline stage for statistical benchmarking.

  Implements the Crucible.Stage behaviour for use in crucible_framework pipelines.
  Uses CrucibleIR.Reliability.Stats configuration for test selection and parameters.

  ## Context Requirements

  The context map must contain:
  - `experiment.reliability.stats` - CrucibleIR.Reliability.Stats configuration
  - `outputs` or `metrics` - Data to analyze (list of numeric values or maps with numeric values)

  ## Returns

  Updated context with `:bench` key containing statistical analysis results.

  ## Example

      # Context from pipeline
      context = %{
        experiment: %{
          reliability: %{
            stats: %CrucibleIR.Reliability.Stats{
              tests: [:ttest, :anova],
              alpha: 0.05,
              confidence_level: 0.95,
              effect_size_type: :cohens_d
            }
          }
        },
        outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
      }

      {:ok, updated_context} = CrucibleBench.Stage.run(context)
      # updated_context.bench contains test results
  """

  alias CrucibleBench.Stats

  # Note: We define the callback functions but don't use @behaviour since
  # crucible_framework may not be a dependency. The framework will call these
  # functions dynamically.

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

  - `{:ok, context}` - Updated context with bench results
  - `{:error, reason}` - If configuration or data is missing/invalid
  """
  def run(context, opts \\ %{}) when is_map(context) do
    with {:ok, stats_config} <- extract_stats_config(context),
         {:ok, data} <- extract_data(context, opts),
         {:ok, results} <- run_tests(data, stats_config, opts) do
      {:ok, Map.put(context, :bench, results)}
    end
  end

  @doc """
  Describes this stage for introspection.

  Returns metadata about the stage including its purpose, requirements, and
  configuration options.

  ## Options

  - `:verbose` - Include detailed information (default: false)
  """
  def describe(opts \\ %{}) do
    verbose = Map.get(opts, :verbose, false)

    base = %{
      name: "CrucibleBench.Stage",
      type: :analysis,
      purpose: "Statistical testing and analysis",
      inputs: [:outputs, :metrics],
      outputs: [:bench],
      config_source: "experiment.reliability.stats"
    }

    if verbose do
      Map.merge(base, %{
        available_tests: [:ttest, :bootstrap, :anova, :mannwhitney, :wilcoxon, :kruskal],
        effect_sizes: [:cohens_d, :eta_squared, :omega_squared],
        corrections: [:bonferroni, :holm, :benjamini_hochberg],
        requirements: [
          "CrucibleIR.Reliability.Stats configuration",
          "Numeric data in :outputs or :metrics"
        ]
      })
    else
      base
    end
  end

  # Private Functions

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

  defp extract_data(context, opts) do
    data_key = Map.get(opts, :data_key, :outputs)

    case Map.get(context, data_key) do
      nil ->
        # Try alternative key
        case Map.get(context, :metrics) do
          nil -> {:error, "No data found in context (tried #{data_key} and :metrics)"}
          data -> validate_data(data)
        end

      data ->
        validate_data(data)
    end
  end

  defp validate_data(data) when is_list(data) do
    if Enum.all?(data, &is_number/1) do
      {:ok, data}
    else
      # Try extracting numeric values from maps
      extract_numeric_values(data)
    end
  end

  defp validate_data(_), do: {:error, "Data must be a list"}

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
          {:ok, values}
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

    # Run tests
    results = %{
      tests: %{},
      config: %{
        alpha: test_opts[:alpha],
        confidence_level: test_opts[:confidence_level],
        tests_requested: tests_to_run
      },
      summary: %{
        n: length(data),
        mean: Stats.mean(data),
        sd: Stats.stdev(data),
        median: Stats.median(data)
      }
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

  defp execute_test(:ttest, data, _opts) when length(data) >= 2 do
    # For single group t-test against mean of 0
    # In a real scenario, you'd have two groups
    # This is a placeholder - typically you'd compare against baseline
    {:ok,
     %{
       test_type: :ttest,
       note: "Single group analysis - requires comparison groups in pipeline",
       data_summary: %{n: length(data), mean: Stats.mean(data), sd: Stats.stdev(data)}
     }}
  end

  defp execute_test(:bootstrap, data, opts) do
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

  defp execute_test(:anova, _data, _opts) do
    # ANOVA requires multiple groups
    {:ok,
     %{
       test_type: :anova,
       note: "Requires multiple groups - not applicable to single group data"
     }}
  end

  defp execute_test(test_type, _data, _opts)
       when test_type in [:mannwhitney, :wilcoxon, :kruskal] do
    {:ok,
     %{
       test_type: test_type,
       note: "Requires comparison groups - not applicable to single group data"
     }}
  end

  defp execute_test(test_type, _data, _opts) do
    {:error, "Unknown test type: #{test_type}"}
  end
end
