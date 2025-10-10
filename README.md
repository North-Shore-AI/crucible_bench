# CrucibleBench - Statistical Testing Framework for AI Research

A comprehensive statistical testing framework designed specifically for AI/ML research in Elixir. CrucibleBench provides rigorous statistical tests, effect size measures, power analysis, and publication-ready reporting.

## Features

- **Parametric Tests**: t-tests (independent, paired), ANOVA
- **Non-Parametric Tests**: Mann-Whitney U, Wilcoxon signed-rank, Kruskal-Wallis
- **Effect Sizes**: Cohen's d, Hedges' g, Glass's delta, eta-squared, omega-squared
- **Power Analysis**: A priori and post-hoc power calculations
- **Confidence Intervals**: Bootstrap and analytical methods
- **Experiment DSL**: High-level API for A/B tests, ablation studies, hyperparameter sweeps
- **Export Formats**: Markdown, LaTeX, HTML for publication

## Design Principles

1. **Statistical Rigor**: All implementations follow established statistical methods
2. **Interpretability**: Every result includes effect sizes and practical significance
3. **Reproducibility**: Complete audit trails for research reproducibility
4. **Peer-Review Ready**: Publication-quality output suitable for academic papers

## Installation

Add `crucible_bench` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crucible_bench, "~> 0.1.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
  ]
end
```

## Quick Start

### Compare Two Groups

```elixir
# Compare control vs treatment groups
control = [0.72, 0.68, 0.75, 0.71, 0.69]
treatment = [0.78, 0.73, 0.81, 0.76, 0.74]

result = CrucibleBench.compare(control, treatment)
# => %CrucibleBench.Result{
#   test: :welch_t_test,
#   p_value: 0.0024,
#   effect_size: %{cohens_d: 1.25, interpretation: "large"},
#   confidence_interval: {0.02, 0.14}
# }
```

### Paired Comparison

```elixir
# Before/after measurements
before = [0.72, 0.68, 0.75, 0.71, 0.69]
after = [0.78, 0.73, 0.81, 0.76, 0.74]

result = CrucibleBench.compare_paired(before, after)
```

### Compare Multiple Groups

```elixir
# Compare 3+ groups with ANOVA
gpt4 = [0.89, 0.91, 0.88, 0.90, 0.92]
claude = [0.87, 0.89, 0.86, 0.88, 0.90]
gemini = [0.84, 0.86, 0.83, 0.85, 0.87]

result = CrucibleBench.compare_multiple([gpt4, claude, gemini])
```

### Effect Size Analysis

```elixir
# Calculate Cohen's d
effect = CrucibleBench.effect_size(control, treatment)
# => %{
#   cohens_d: 1.25,
#   interpretation: "large",
#   mean1: 0.71,
#   mean2: 0.764
# }
```

### Confidence Intervals

```elixir
# Calculate 95% CI for mean
data = [0.85, 0.87, 0.84, 0.86, 0.88]
ci = CrucibleBench.confidence_interval(data, :mean)
# => %{interval: {0.8432, 0.8768}, method: :analytical}

# Bootstrap CI for median
ci = CrucibleBench.confidence_interval(data, :median, method: :bootstrap)
```

### Power Analysis

```elixir
# A priori: Calculate required sample size
result = CrucibleBench.power_analysis(:t_test,
  analysis_type: :a_priori,
  effect_size: 0.5,    # Medium effect
  alpha: 0.05,
  power: 0.80          # 80% power
)
# => %{n_per_group: 64, recommendation: "Collect at least 64 samples per group..."}

# Post-hoc: Calculate achieved power
result = CrucibleBench.power_analysis(:t_test,
  analysis_type: :post_hoc,
  effect_size: 0.5,
  n_per_group: 30,
  alpha: 0.05
)
# => %{power: 0.548, recommendation: "Marginal power..."}
```

## High-Level Experiment DSL

### A/B Testing

```elixir
result = CrucibleBench.experiment(:ab_test,
  control: control_scores,
  treatment: treatment_scores,
  name: "Prompt Engineering Test"
)

# Comprehensive output includes:
# - Statistical significance
# - Effect size with interpretation
# - Power analysis
# - Recommendations
```

### Ablation Study

```elixir
result = CrucibleBench.experiment(:ablation,
  baseline: [0.85, 0.87, 0.84, 0.86, 0.88],
  without_component: [0.78, 0.76, 0.79, 0.77, 0.75],
  component_name: "Ensemble Voting"
)

# Shows performance drop and component importance
```

### Hyperparameter Sweep

```elixir
result = CrucibleBench.experiment(:hyperparameter_sweep,
  configurations: [config_a, config_b, config_c],
  labels: ["Config A", "Config B", "Config C"]
)

# Identifies best configuration with pairwise comparisons
```

## Export Results

### Markdown

```elixir
markdown = CrucibleBench.Export.to_markdown(result)
IO.puts(markdown)
```

### LaTeX

```elixir
latex = CrucibleBench.Export.to_latex(result)
# Generates LaTeX table for academic papers
```

### HTML

```elixir
html = CrucibleBench.Export.to_html(result)
# Generates styled HTML report
```

### Experiment Reports

```elixir
report = CrucibleBench.Export.experiment_to_markdown(ab_result)
# Comprehensive markdown report with interpretations
```

## Statistical Tests Reference

### Parametric Tests

| Test | Function | Use Case |
|------|----------|----------|
| Independent t-test | `CrucibleBench.Stats.TTest.test/3` | Compare 2 independent groups |
| Welch's t-test | `CrucibleBench.Stats.TTest.test/3` | Compare 2 groups (unequal variance) |
| Paired t-test | `CrucibleBench.Stats.PairedTTest.test/3` | Compare 2 related groups |
| One-way ANOVA | `CrucibleBench.Stats.ANOVA.one_way/2` | Compare 3+ independent groups |

### Non-Parametric Tests

| Test | Function | Use Case |
|------|----------|----------|
| Mann-Whitney U | `CrucibleBench.Stats.MannWhitney.test/3` | Non-parametric alternative to t-test |
| Wilcoxon signed-rank | `CrucibleBench.Stats.Wilcoxon.test/3` | Non-parametric alternative to paired t-test |
| Kruskal-Wallis | `CrucibleBench.Stats.KruskalWallis.test/2` | Non-parametric alternative to ANOVA |

### Effect Sizes

| Measure | Function | Interpretation |
|---------|----------|----------------|
| Cohen's d | `CrucibleBench.Stats.EffectSize.cohens_d/2` | Standardized mean difference |
| Hedges' g | `CrucibleBench.Stats.EffectSize.hedges_g/2` | Bias-corrected Cohen's d |
| Glass's delta | `CrucibleBench.Stats.EffectSize.glass_delta/2` | Using control SD only |
| Eta-squared | Included in ANOVA results | Proportion of variance explained |

## Effect Size Interpretation

Based on Cohen (1988):

| Cohen's d | Interpretation |
|-----------|----------------|
| < 0.2 | Negligible |
| 0.2 - 0.5 | Small |
| 0.5 - 0.8 | Medium |
| > 0.8 | Large |

| Eta-squared (η²) | Interpretation |
|------------------|----------------|
| < 0.01 | Negligible |
| 0.01 - 0.06 | Small |
| 0.06 - 0.14 | Medium |
| > 0.14 | Large |

## Module Structure

```
lib/crucible_bench/
├── bench.ex                          # Main API
├── result.ex                         # Result struct
├── stats.ex                          # Core statistics
├── analysis.ex                       # High-level analysis
├── experiment.ex                     # Experiment DSL
├── export.ex                         # Export/reporting
└── stats/
    ├── t_test.ex                     # Independent t-test
    ├── paired_t_test.ex              # Paired t-test
    ├── anova.ex                      # ANOVA
    ├── mann_whitney.ex               # Mann-Whitney U
    ├── wilcoxon.ex                   # Wilcoxon signed-rank
    ├── kruskal_wallis.ex             # Kruskal-Wallis
    ├── effect_size.ex                # Effect size measures
    ├── confidence_interval.ex        # CI calculations
    ├── power.ex                      # Power analysis
    └── distributions.ex              # Probability distributions
```

## Examples

See `examples/basic_usage.exs` for comprehensive examples covering:

1. Independent samples t-test
2. Paired t-test
3. One-way ANOVA
4. Effect size analysis
5. Confidence intervals
6. Power analysis
7. A/B test experiment
8. Ablation study
9. Hyperparameter sweep
10. Result export

Run examples:

```bash
mix run examples/basic_usage.exs
```

## Testing

Run the test suite:

```bash
mix test
```

Run specific tests:

```bash
mix test test/bench_test.exs
mix test test/stats_test.exs
mix test test/effect_size_test.exs
```

## Best Practices for AI Research

### 1. Always Report Effect Sizes

P-values alone don't tell the full story. Always include effect sizes:

```elixir
result = CrucibleBench.compare(control, treatment)
IO.puts("P-value: #{result.p_value}")
IO.puts("Effect size: #{result.effect_size.cohens_d} (#{result.effect_size.interpretation})")
```

### 2. Check Statistical Power

Ensure your study has adequate power:

```elixir
power = CrucibleBench.power_analysis(:t_test,
  analysis_type: :post_hoc,
  effect_size: observed_effect,
  n_per_group: n,
  alpha: 0.05
)

if power.power < 0.8 do
  IO.puts("Warning: Underpowered study! #{power.recommendation}")
end
```

### 3. Use Confidence Intervals

CIs provide more information than p-values:

```elixir
result = CrucibleBench.compare(group1, group2)
{lower, upper} = result.confidence_interval
IO.puts("95% CI: [#{lower}, #{upper}]")
```

### 4. Consider Practical Significance

Statistical significance ≠ practical significance:

```elixir
if result.p_value < 0.05 and abs(effect.cohens_d) < 0.2 do
  IO.puts("Statistically significant but negligible effect size")
end
```

### 5. Use Experiment DSL for Complex Studies

The experiment DSL automates best practices:

```elixir
result = CrucibleBench.experiment(:ab_test,
  control: control,
  treatment: treatment,
  name: "My Experiment"
)

# Automatically includes:
# - Appropriate test selection
# - Effect size calculation
# - Power analysis
# - Recommendations
```

## Common Use Cases in AI Research

### Compare Model Performance

```elixir
model_a_scores = [0.85, 0.87, 0.84, 0.86, 0.88]
model_b_scores = [0.88, 0.90, 0.89, 0.91, 0.87]

result = CrucibleBench.compare(model_a_scores, model_b_scores)
effect = CrucibleBench.effect_size(model_a_scores, model_b_scores)
```

### Test Prompt Engineering

```elixir
baseline_prompt = [0.72, 0.68, 0.75, 0.71, 0.69]
optimized_prompt = [0.78, 0.73, 0.81, 0.76, 0.74]

result = CrucibleBench.experiment(:ab_test,
  control: baseline_prompt,
  treatment: optimized_prompt,
  name: "Prompt Optimization"
)
```

### Evaluate Architecture Changes

```elixir
baseline = [0.85, 0.87, 0.84, 0.86, 0.88]
new_arch = [0.88, 0.90, 0.89, 0.91, 0.87]

result = CrucibleBench.compare(baseline, new_arch)
markdown = CrucibleBench.Export.to_markdown(result)
File.write!("results.md", markdown)
```

### Ablation Studies

```elixir
full_system = [0.85, 0.87, 0.84, 0.86, 0.88]
without_cache = [0.78, 0.76, 0.79, 0.77, 0.75]

result = CrucibleBench.experiment(:ablation,
  baseline: full_system,
  without_component: without_cache,
  component_name: "Response Cache"
)
```

## Limitations

- **Sample Size**: Most tests assume n ≥ 30 for asymptotic properties. Use bootstrap methods for smaller samples.
- **Normality**: Parametric tests assume normality. Bench automatically suggests non-parametric alternatives when assumptions are violated.
- **Independence**: All tests assume independent observations. Use appropriate designs for repeated measures.

## References

### Statistical Methods

- Cohen, J. (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Routledge.
- Welch, B. L. (1947). The generalization of "Student's" problem when several different population variances are involved. *Biometrika*, 34(1-2), 28-35.
- Kruskal, W. H., & Wallis, W. A. (1952). Use of ranks in one-criterion variance analysis. *Journal of the American Statistical Association*, 47(260), 583-621.

### AI Research Statistics

- Dror, R., et al. (2018). The hitchhiker's guide to testing statistical significance in natural language processing. *Proceedings of ACL*.
- Demšar, J. (2006). Statistical comparisons of classifiers over multiple data sets. *Journal of Machine Learning Research*, 7, 1-30.

## Contributing

This is part of the ElixirAI Research Infrastructure. See the main project documentation for contribution guidelines.

## License

Copyright (c) 2025 ElixirAI Research Initiative
