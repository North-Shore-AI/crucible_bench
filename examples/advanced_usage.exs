# Advanced Usage Examples for Bench Statistical Framework

# Demonstrates advanced features and integration patterns

alias CrucibleBench
alias CrucibleBench.{Stats, Export, Analysis}

IO.puts("=== Advanced Statistical Analysis ===\n")

# Example 1: Custom Effect Size Calculations
IO.puts("1. Multiple Effect Size Measures")
group1 = [5.0, 5.2, 4.8, 5.1, 4.9, 5.3, 5.0, 5.2]
group2 = [6.0, 6.2, 5.8, 6.1, 5.9, 6.3, 6.0, 6.2]

cohens_d = Stats.EffectSize.cohens_d(group1, group2)
hedges_g = Stats.EffectSize.hedges_g(group1, group2)
glass_delta = Stats.EffectSize.glass_delta(group1, group2)

IO.puts("Cohen's d: #{Float.round(cohens_d.cohens_d, 3)} (#{cohens_d.interpretation})")
IO.puts("Hedges' g: #{Float.round(hedges_g.hedges_g, 3)} (bias-corrected)")
IO.puts("Glass's Δ: #{Float.round(glass_delta.glass_delta, 3)} (control SD only)\n")

# Example 2: Bootstrap Confidence Intervals
IO.puts("2. Bootstrap vs Analytical Confidence Intervals")
data = [0.85, 0.87, 0.84, 0.86, 0.88, 0.83, 0.89, 0.85, 0.87, 0.86]

analytical_ci = CrucibleBench.confidence_interval(data, :mean, method: :analytical)

bootstrap_ci =
  CrucibleBench.confidence_interval(data, :median, method: :bootstrap, iterations: 5000)

IO.puts("Analytical CI (mean): #{inspect(analytical_ci.interval)}")
IO.puts("Bootstrap CI (median): #{inspect(bootstrap_ci.interval)}")
IO.puts("Bootstrap SD: #{Float.round(bootstrap_ci.bootstrap_distribution.sd, 4)}\n")

# Example 3: Power Curves - Sample Size vs Power
IO.puts("3. Power Analysis for Different Sample Sizes")
effect_size = 0.5
sample_sizes = [10, 20, 30, 50, 100, 200]

IO.puts("Effect size: #{effect_size} (medium)")
IO.puts("\nn per group | Power")
IO.puts("------------|-------")

for n <- sample_sizes do
  power_result =
    CrucibleBench.power_analysis(:t_test,
      analysis_type: :post_hoc,
      effect_size: effect_size,
      n_per_group: n,
      alpha: 0.05
    )

  IO.puts(
    "#{String.pad_leading(to_string(n), 11)} | #{Float.round(power_result.power * 100, 1)}%"
  )
end

IO.puts("")

# Example 4: Non-Parametric Tests for Non-Normal Data
IO.puts("4. Handling Non-Normal Data")

# Skewed data with outliers
control_skewed = [120, 135, 118, 142, 125, 890, 130, 128]
treatment_skewed = [98, 105, 102, 110, 95, 108, 100, 103]

# Automatic test selection detects non-normality
parametric_result = CrucibleBench.compare(control_skewed, treatment_skewed, test: :welch_t_test)

nonparametric_result =
  CrucibleBench.compare(control_skewed, treatment_skewed, test: :mann_whitney)

IO.puts("Parametric (t-test) p-value: #{Float.round(parametric_result.p_value, 4)}")
IO.puts("Non-parametric (Mann-Whitney) p-value: #{Float.round(nonparametric_result.p_value, 4)}")

IO.puts(
  "Recommended: Use non-parametric test for skewed data with outliers (890 in control group)\n"
)

# Example 5: Multiple Comparison with Post-Hoc Tests
IO.puts("5. ANOVA with Detailed Analysis")
model_a = [0.89, 0.91, 0.88, 0.90, 0.92, 0.87]
model_b = [0.87, 0.89, 0.86, 0.88, 0.90, 0.85]
model_c = [0.84, 0.86, 0.83, 0.85, 0.87, 0.82]
model_d = [0.78, 0.80, 0.77, 0.79, 0.81, 0.76]

anova_result = CrucibleBench.compare_multiple([model_a, model_b, model_c, model_d])

IO.puts("Overall ANOVA:")
IO.puts("  F-statistic: #{Float.round(anova_result.statistic, 3)}")
IO.puts("  P-value: #{Float.round(anova_result.p_value, 6)}")
IO.puts("  η² (eta-squared): #{Float.round(anova_result.effect_size.eta_squared, 3)}")
IO.puts("  ω² (omega-squared): #{Float.round(anova_result.effect_size.omega_squared, 3)}")
IO.puts("")

# Pairwise comparisons
IO.puts("Pairwise Comparisons:")
groups = [model_a, model_b, model_c, model_d]
labels = ["Model A", "Model B", "Model C", "Model D"]

for i <- 0..(length(groups) - 2), j <- (i + 1)..(length(groups) - 1) do
  result = CrucibleBench.compare(Enum.at(groups, i), Enum.at(groups, j))
  sig = if result.p_value < 0.05, do: "*", else: ""

  IO.puts(
    "  #{Enum.at(labels, i)} vs #{Enum.at(labels, j)}: p = #{Float.round(result.p_value, 4)} #{sig}"
  )
end

IO.puts("")

# Example 6: Complex Experiment Workflow
IO.puts("6. Complete Research Workflow")

# Simulate a complete research study
baseline_scores = [0.72, 0.74, 0.71, 0.73, 0.70, 0.75, 0.72, 0.74]
intervention_scores = [0.78, 0.80, 0.77, 0.79, 0.76, 0.81, 0.78, 0.80]

# Step 1: Run experiment
experiment_result =
  CrucibleBench.experiment(:ab_test,
    control: baseline_scores,
    treatment: intervention_scores,
    name: "Training Intervention Study"
  )

# Step 2: Check power
if experiment_result.power < 0.8 do
  required_n =
    CrucibleBench.power_analysis(:t_test,
      analysis_type: :a_priori,
      effect_size: abs(experiment_result.effect_size.cohens_d),
      alpha: 0.05,
      power: 0.80
    )

  IO.puts("Warning: Study is underpowered!")
  IO.puts("  Current power: #{Float.round(experiment_result.power * 100, 1)}%")
  IO.puts("  Need n=#{required_n.n_per_group} per group for 80% power")
  IO.puts("")
end

# Step 3: Generate report
markdown_report = Export.experiment_to_markdown(experiment_result)

# Step 4: Save to file (demonstration - not actually saving)
IO.puts("Generated markdown report:")
IO.puts(String.slice(markdown_report, 0..500) <> "...\n")

# Example 7: Comparing Effect Sizes Across Studies
IO.puts("7. Meta-Analysis of Effect Sizes")

studies = [
  {[0.70, 0.72, 0.68], [0.75, 0.77, 0.73], "Study 1"},
  {[0.65, 0.67, 0.63], [0.72, 0.74, 0.70], "Study 2"},
  {[0.75, 0.77, 0.73], [0.80, 0.82, 0.78], "Study 3"}
]

IO.puts("Study    | Cohen's d | 95% CI | Interpretation")
IO.puts("---------|-----------|--------|----------------")

for {control, treatment, name} <- studies do
  effect = CrucibleBench.effect_size(control, treatment)
  result = CrucibleBench.compare(control, treatment)
  {lower, upper} = result.confidence_interval

  IO.puts(
    "#{String.pad_trailing(name, 8)} | #{String.pad_leading(Float.round(effect.cohens_d, 2) |> to_string(), 9)} | [#{Float.round(lower, 2)}, #{Float.round(upper, 2)}] | #{effect.interpretation}"
  )
end

IO.puts("")

# Example 8: Custom Statistical Workflow
IO.puts("8. Custom Analysis Pipeline")

# Function to perform complete analysis
analyze_experiment = fn control, treatment, name ->
  # Test normality
  _control_normal = Analysis.compare_groups(control, control, check_assumptions: true)
  # Note: In real use, you'd check skewness/kurtosis properly

  # Select and run test
  result = CrucibleBench.compare(control, treatment)
  effect = CrucibleBench.effect_size(control, treatment)

  # Power analysis
  power =
    CrucibleBench.power_analysis(:t_test,
      analysis_type: :post_hoc,
      effect_size: abs(effect.cohens_d),
      n_per_group: length(control),
      alpha: 0.05
    )

  %{
    name: name,
    significant: result.p_value < 0.05,
    p_value: result.p_value,
    effect_size: effect.cohens_d,
    interpretation: effect.interpretation,
    power: power.power,
    adequate_power: power.power >= 0.8
  }
end

# Run multiple experiments
experiments = [
  {[0.70, 0.72, 0.68, 0.71, 0.69], [0.75, 0.77, 0.73, 0.76, 0.74], "Exp 1"},
  {[0.65, 0.67, 0.63, 0.66, 0.64], [0.70, 0.72, 0.68, 0.71, 0.69], "Exp 2"},
  {[0.80, 0.82, 0.78, 0.81, 0.79], [0.83, 0.85, 0.81, 0.84, 0.82], "Exp 3"}
]

results =
  for {control, treatment, name} <- experiments, do: analyze_experiment.(control, treatment, name)

IO.puts("Experiment Summary:")

for r <- results do
  status = if r.significant, do: "SIG", else: "n.s."
  power_status = if r.adequate_power, do: "✓", else: "✗"

  IO.puts(
    "#{r.name}: #{status} (p=#{Float.round(r.p_value, 3)}, d=#{Float.round(r.effect_size, 2)}, power #{power_status})"
  )
end

IO.puts("\n=== Advanced Examples Complete ===")
