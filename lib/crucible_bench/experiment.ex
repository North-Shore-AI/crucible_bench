defmodule CrucibleBench.Experiment do
  @moduledoc """
  High-level experiment DSL for common research patterns.

  Provides convenient functions for A/B testing, ablation studies,
  and hyperparameter sweeps.
  """

  alias CrucibleBench.{Analysis, Stats}
  alias CrucibleBench.Stats.{EffectSize, Power, MultipleComparisons}

  @doc """
  Run an experiment with automatic analysis.

  ## Experiment Types

  - `:ab_test` - Compare control vs treatment
  - `:ablation` - Test impact of removing components
  - `:hyperparameter_sweep` - Compare multiple configurations

  ## Examples

      # A/B Test
      CrucibleBench.Experiment.run(:ab_test,
        control: [0.72, 0.68, 0.75],
        treatment: [0.78, 0.73, 0.81],
        name: "Prompt Engineering")

      # Ablation Study
      CrucibleBench.Experiment.run(:ablation,
        baseline: [0.85, 0.87, 0.84],
        without_component: [0.78, 0.76, 0.79],
        component_name: "Ensemble Voting")
  """
  def run(:ab_test, opts) do
    control = Keyword.fetch!(opts, :control)
    treatment = Keyword.fetch!(opts, :treatment)
    name = Keyword.get(opts, :name, "A/B Test")

    # Run test
    result = Analysis.compare_groups(control, treatment)

    # Calculate effect size
    effect = EffectSize.cohens_d(control, treatment)

    # Power analysis
    power_result =
      Power.analyze(:t_test,
        analysis_type: :post_hoc,
        effect_size: abs(effect.cohens_d),
        n_per_group: length(control),
        alpha: 0.05
      )

    # Compile comprehensive report
    %{
      experiment_type: :ab_test,
      name: name,
      significant?: result.p_value < 0.05,
      p_value: result.p_value,
      test_used: result.test,
      effect_size: effect,
      power: power_result.power,
      sample_sizes: %{
        control: length(control),
        treatment: length(treatment)
      },
      means: %{
        control: Stats.mean(control),
        treatment: Stats.mean(treatment),
        difference: Stats.mean(treatment) - Stats.mean(control)
      },
      confidence_interval: result.confidence_interval,
      interpretation: interpret_ab_test(result, effect, power_result),
      recommendation: generate_recommendation(result, effect, power_result),
      raw_result: result
    }
  end

  def run(:ablation, opts) do
    baseline = Keyword.fetch!(opts, :baseline)
    without_component = Keyword.fetch!(opts, :without_component)
    component_name = Keyword.get(opts, :component_name, "Component")

    # Run test (ablated version vs baseline)
    result = Analysis.compare_groups(baseline, without_component)

    # Calculate effect size
    effect = EffectSize.cohens_d(baseline, without_component)

    # Calculate performance drop
    mean_baseline = Stats.mean(baseline)
    mean_without = Stats.mean(without_component)
    performance_drop = mean_baseline - mean_without
    percent_drop = performance_drop / mean_baseline * 100

    %{
      experiment_type: :ablation,
      component_name: component_name,
      significant_impact?: result.p_value < 0.05,
      p_value: result.p_value,
      effect_size: effect,
      performance_drop: %{
        absolute: performance_drop,
        percent: percent_drop
      },
      means: %{
        baseline: mean_baseline,
        without_component: mean_without
      },
      confidence_interval: result.confidence_interval,
      interpretation: interpret_ablation(result, effect, component_name, percent_drop),
      raw_result: result
    }
  end

  def run(:hyperparameter_sweep, opts) do
    configurations = Keyword.fetch!(opts, :configurations)
    labels = Keyword.get(opts, :labels, Enum.map(1..length(configurations), &"Config #{&1}"))
    correction_method = Keyword.get(opts, :correction_method, :holm)

    unless length(configurations) >= 2 do
      raise ArgumentError, "Need at least 2 configurations"
    end

    # Run omnibus test
    omnibus_result = Analysis.compare_multiple(configurations)

    # Calculate all pairwise comparisons
    pairwise_results = calculate_pairwise_comparisons(configurations, labels, correction_method)

    # Find best configuration
    means = Enum.map(configurations, &Stats.mean/1)
    {best_mean, best_idx} = Enum.with_index(means) |> Enum.max_by(fn {m, _} -> m end)
    best_config = Enum.at(labels, best_idx)

    %{
      experiment_type: :hyperparameter_sweep,
      configurations_tested: length(configurations),
      omnibus_test: %{
        significant?: omnibus_result.p_value < 0.05,
        p_value: omnibus_result.p_value,
        test_used: omnibus_result.test,
        effect_size: omnibus_result.effect_size
      },
      best_configuration: %{
        name: best_config,
        mean: best_mean,
        rank: 1
      },
      configuration_means: Enum.zip(labels, means) |> Map.new(),
      pairwise_comparisons: pairwise_results,
      correction_method: correction_method,
      interpretation: interpret_sweep(omnibus_result, best_config, best_mean),
      raw_result: omnibus_result
    }
  end

  defp calculate_pairwise_comparisons(configurations, labels, correction_method) do
    # Calculate all pairwise comparisons
    comparisons =
      for i <- 0..(length(configurations) - 2),
          j <- (i + 1)..(length(configurations) - 1) do
        config_i = Enum.at(configurations, i)
        config_j = Enum.at(configurations, j)
        label_i = Enum.at(labels, i)
        label_j = Enum.at(labels, j)

        result = Analysis.compare_groups(config_i, config_j)
        effect = EffectSize.cohens_d(config_i, config_j)

        %{
          comparison: "#{label_i} vs #{label_j}",
          p_value: result.p_value,
          effect_size: effect.cohens_d,
          mean_diff: Stats.mean(config_i) - Stats.mean(config_j)
        }
      end

    # Apply multiple comparison correction
    p_values = Enum.map(comparisons, & &1.p_value)
    adjusted_p_values = MultipleComparisons.correct(p_values, method: correction_method)

    # Merge adjusted p-values back into comparisons
    Enum.zip(comparisons, adjusted_p_values)
    |> Enum.map(fn {comp, adj_result} ->
      Map.merge(comp, %{
        adjusted_p_value: adj_result.adjusted_p_value,
        significant_original: adj_result.significant_original,
        significant_adjusted: adj_result.significant_adjusted,
        correction_method: correction_method
      })
    end)
  end

  defp interpret_ab_test(result, effect, power_result) do
    sig_text = if result.p_value < 0.05, do: "significant", else: "not significant"
    effect_text = effect.interpretation
    power_text = if power_result.power >= 0.8, do: "adequate", else: "insufficient"

    """
    The treatment group showed a #{sig_text} difference from control (p = #{Float.round(result.p_value, 4)}).
    Effect size: #{effect_text} (Cohen's d = #{Float.round(effect.cohens_d, 3)}).
    Statistical power: #{power_text} (#{Float.round(power_result.power * 100, 1)}%).
    """
    |> String.trim()
  end

  defp interpret_ablation(result, effect, component_name, percent_drop) do
    if result.p_value < 0.05 do
      direction = if percent_drop > 0, do: "decreased", else: "increased"

      """
      Removing #{component_name} significantly #{direction} performance by #{abs(Float.round(percent_drop, 2))}%.
      Effect size: #{effect.interpretation} (Cohen's d = #{Float.round(effect.cohens_d, 3)}).
      This component appears to be #{if percent_drop > 0, do: "important", else: "detrimental"} to the system.
      """
    else
      """
      Removing #{component_name} did not significantly affect performance (p = #{Float.round(result.p_value, 4)}).
      This component may be redundant or its effect is too small to detect with current sample size.
      """
    end
    |> String.trim()
  end

  defp interpret_sweep(omnibus_result, best_config, best_mean) do
    if omnibus_result.p_value < 0.05 do
      """
      Significant differences were found between configurations (p = #{Float.round(omnibus_result.p_value, 4)}).
      Best performing configuration: #{best_config} (mean = #{Float.round(best_mean, 4)}).
      Effect size: #{omnibus_result.effect_size.interpretation}.
      """
    else
      """
      No significant differences were found between configurations (p = #{Float.round(omnibus_result.p_value, 4)}).
      All configurations perform similarly. #{best_config} had the highest mean (#{Float.round(best_mean, 4)}),
      but this difference is not statistically significant.
      """
    end
    |> String.trim()
  end

  defp generate_recommendation(result, effect, power_result) do
    cond do
      result.p_value >= 0.05 and power_result.power < 0.8 ->
        "Increase sample size to achieve 80% power. Current power is only #{Float.round(power_result.power * 100, 1)}%."

      result.p_value < 0.05 and abs(effect.cohens_d) < 0.2 ->
        "While statistically significant, the effect size is negligible. Consider practical significance."

      result.p_value < 0.05 and abs(effect.cohens_d) >= 0.5 ->
        "Both statistically and practically significant. Treatment shows clear improvement."

      true ->
        "Results are inconclusive. Consider collecting more data or adjusting the intervention."
    end
  end
end
