# Basic Usage Examples for Bench Statistical Framework

# Load Bench
alias CrucibleBench
alias CrucibleBench.Export

IO.puts("=== Basic Statistical Tests ===\n")

# Example 1: Compare two independent groups (t-test)
IO.puts("1. Independent Samples t-test")
control_scores = [0.72, 0.68, 0.75, 0.71, 0.69, 0.73, 0.70, 0.74]
treatment_scores = [0.78, 0.73, 0.81, 0.76, 0.74, 0.79, 0.77, 0.80]

result = CrucibleBench.compare(control_scores, treatment_scores)
IO.puts("P-value: #{result.p_value}")
IO.puts("Test used: #{result.test}")
IO.puts("Interpretation: #{result.interpretation}\n")

# Example 2: Paired comparison (before/after)
IO.puts("2. Paired t-test (Before/After)")
before_training = [0.65, 0.68, 0.63, 0.70, 0.66, 0.69, 0.67]
after_training = [0.72, 0.75, 0.70, 0.78, 0.73, 0.76, 0.74]

paired_result = CrucibleBench.compare_paired(before_training, after_training)
IO.puts("P-value: #{paired_result.p_value}")
IO.puts("Mean improvement: #{paired_result.metadata.mean_diff}")
IO.puts("Interpretation: #{paired_result.interpretation}\n")

# Example 3: Compare multiple groups (ANOVA)
IO.puts("3. One-way ANOVA (Multiple Groups)")
gpt4_scores = [0.89, 0.91, 0.88, 0.90, 0.92, 0.87, 0.91]
claude_scores = [0.87, 0.89, 0.86, 0.88, 0.90, 0.85, 0.88]
gemini_scores = [0.84, 0.86, 0.83, 0.85, 0.87, 0.82, 0.85]
llama_scores = [0.78, 0.80, 0.77, 0.79, 0.81, 0.76, 0.79]

anova_result =
  CrucibleBench.compare_multiple([gpt4_scores, claude_scores, gemini_scores, llama_scores])

IO.puts("P-value: #{anova_result.p_value}")
IO.puts("Effect size (η²): #{anova_result.effect_size.eta_squared}")
IO.puts("Interpretation: #{anova_result.interpretation}\n")

# Example 4: Effect size calculation
IO.puts("4. Effect Size Analysis")
effect = CrucibleBench.effect_size(control_scores, treatment_scores)
IO.puts("Cohen's d: #{effect.cohens_d}")
IO.puts("Interpretation: #{effect.interpretation}")
IO.puts("Pooled SD: #{effect.pooled_sd}\n")

# Example 5: Confidence intervals
IO.puts("5. Confidence Intervals")
data = [0.85, 0.87, 0.84, 0.86, 0.88, 0.83, 0.89, 0.85, 0.87]
ci = CrucibleBench.confidence_interval(data, :mean, confidence_level: 0.95)
{lower, upper} = ci.interval
IO.puts("95% CI for mean: [#{Float.round(lower, 4)}, #{Float.round(upper, 4)}]")
IO.puts("Point estimate: #{ci.point_estimate}\n")

# Example 6: Power analysis
IO.puts("6. Power Analysis")

# A priori: Calculate required sample size
power_result =
  CrucibleBench.power_analysis(:t_test,
    analysis_type: :a_priori,
    # Medium effect
    effect_size: 0.5,
    alpha: 0.05,
    power: 0.80
  )

IO.puts("Required sample size per group: #{power_result.n_per_group}")
IO.puts("Recommendation: #{power_result.recommendation}\n")

# Post-hoc: Calculate achieved power
achieved_power =
  CrucibleBench.power_analysis(:t_test,
    analysis_type: :post_hoc,
    effect_size: 0.5,
    n_per_group: length(control_scores),
    alpha: 0.05
  )

IO.puts(
  "Achieved power with n=#{length(control_scores)}: #{Float.round(achieved_power.power * 100, 1)}%"
)

IO.puts("Recommendation: #{achieved_power.recommendation}\n")

IO.puts("\n=== Advanced Experiments ===\n")

# Example 7: A/B Test Experiment
IO.puts("7. A/B Test Experiment")

ab_result =
  CrucibleBench.experiment(:ab_test,
    control: control_scores,
    treatment: treatment_scores,
    name: "Prompt Engineering A/B Test"
  )

IO.puts("Experiment: #{ab_result.name}")
IO.puts("Significant? #{ab_result.significant?}")
IO.puts("Effect size: #{ab_result.effect_size.interpretation}")
IO.puts("Statistical power: #{Float.round(ab_result.power * 100, 1)}%")
IO.puts("\nInterpretation:")
IO.puts(ab_result.interpretation)
IO.puts("\nRecommendation:")
IO.puts(ab_result.recommendation)
IO.puts("")

# Example 8: Ablation Study
IO.puts("8. Ablation Study")
baseline_perf = [0.85, 0.87, 0.84, 0.86, 0.88, 0.85, 0.87]
without_ensemble = [0.78, 0.76, 0.79, 0.77, 0.75, 0.78, 0.76]

ablation_result =
  CrucibleBench.experiment(:ablation,
    baseline: baseline_perf,
    without_component: without_ensemble,
    component_name: "Ensemble Voting"
  )

IO.puts("Component: #{ablation_result.component_name}")
IO.puts("Significant impact? #{ablation_result.significant_impact?}")
IO.puts("Performance drop: #{Float.round(ablation_result.performance_drop.percent, 2)}%")
IO.puts("\nInterpretation:")
IO.puts(ablation_result.interpretation)
IO.puts("")

# Example 9: Hyperparameter Sweep
IO.puts("9. Hyperparameter Sweep")
config_a = [0.85, 0.87, 0.84, 0.86]
config_b = [0.88, 0.90, 0.89, 0.91]
config_c = [0.82, 0.84, 0.83, 0.85]
config_d = [0.79, 0.81, 0.80, 0.82]

sweep_result =
  CrucibleBench.experiment(:hyperparameter_sweep,
    configurations: [config_a, config_b, config_c, config_d],
    labels: ["Config A", "Config B", "Config C", "Config D"]
  )

IO.puts("Configurations tested: #{sweep_result.configurations_tested}")
IO.puts("Best configuration: #{sweep_result.best_configuration.name}")
IO.puts("Best mean performance: #{Float.round(sweep_result.best_configuration.mean, 4)}")
IO.puts("\nInterpretation:")
IO.puts(sweep_result.interpretation)
IO.puts("")

# Example 10: Export results
IO.puts("10. Exporting Results")
IO.puts("\n--- Markdown Format ---")
markdown = Export.to_markdown(result)
IO.puts(markdown)

IO.puts("\n--- Experiment Report ---")
exp_markdown = Export.experiment_to_markdown(ab_result)
IO.puts(exp_markdown)

IO.puts("\n=== Examples Complete ===")
