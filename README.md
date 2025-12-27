<p align="center">
  <img src="assets/crucible_bench.svg" alt="Bench" width="150"/>
</p>

# CrucibleBench

[![Elixir](https://img.shields.io/badge/elixir-1.14+-purple.svg)](https://elixir-lang.org)
[![Hex.pm](https://img.shields.io/hexpm/v/crucible_bench.svg)](https://hex.pm/packages/crucible_bench)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/crucible_bench)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/North-Shore-AI/crucible_bench/blob/main/LICENSE)

**Statistical Testing Framework for AI Research**

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
    {:crucible_bench, "~> 0.4.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
    {:crucible_bench, github: "North-Shore-AI/crucible_bench"}
  ]
end
```

## Stage Contract

`CrucibleBench.Stage` implements the `Crucible.Stage` behaviour from crucible_framework.

### Options

- `:tests` - Statistical tests to run (default: `[:ttest]`)
- `:alpha` - Significance level (default: 0.05)
- `:confidence_level` - Confidence level (default: 0.95)
- `:bootstrap_iterations` - Bootstrap iterations (default: 1000)
- `:data_source` - Data source (`:outputs`, `:metrics`, or `{:custom, fn}`)

### Schema Introspection

```elixir
# Get stage schema
schema = CrucibleBench.Stage.describe(%{})
# => %{
#   __schema_version__: "1.0.0",
#   name: :bench,
#   description: "Statistical benchmarking and hypothesis testing",
#   required: [],
#   optional: [:tests, :alpha, :confidence_level, :bootstrap_iterations, :data_source],
#   types: %{...},
#   defaults: %{tests: [:ttest], alpha: 0.05, ...},
#   __extensions__: %{bench: %{...}}
# }
```

## Pipeline Integration

CrucibleBench v0.4.0+ provides `CrucibleBench.Stage` for seamless integration with crucible_framework pipelines:

```elixir
# In your pipeline configuration
context = %{
  experiment: %{
    reliability: %{
      stats: %CrucibleIR.Reliability.Stats{
        tests: [:ttest, :bootstrap],
        alpha: 0.05,
        confidence_level: 0.95,
        bootstrap_iterations: 2000
      }
    }
  },
  outputs: [0.85, 0.87, 0.84, 0.86, 0.88]
}

# Run statistical analysis
{:ok, updated_context} = CrucibleBench.Stage.run(context)

# Access results
updated_context.bench.tests
# => %{
#   ttest: %{test_type: :ttest, ...},
#   bootstrap: %{test_type: :bootstrap, confidence_interval: {0.84, 0.88}, ...}
# }

updated_context.bench.summary
# => %{n: 5, mean: 0.86, sd: 0.0141, median: 0.86}
```

### Advanced Stage Configuration

The Stage supports multiple data layouts for different test types:

```elixir
# Two-group comparison (t-test, Mann-Whitney)
context = %{
  experiment: %{reliability: %{stats: stats_config}},
  control: [0.72, 0.68, 0.75, 0.71, 0.69],
  treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
}

{:ok, ctx} = CrucibleBench.Stage.run(context)
ctx.bench.tests.ttest
# => %{
#   test_type: :ttest,
#   statistic: -3.42,
#   p_value: 0.0089,
#   significant: true,
#   effect_size: %{cohens_d: -2.16, interpretation: "large"},
#   confidence_interval: {-0.095, -0.019}
# }

# Multi-group comparison (ANOVA, Kruskal-Wallis)
context = %{
  experiment: %{
    reliability: %{
      stats: %CrucibleIR.Reliability.Stats{
        tests: [:anova],
        alpha: 0.05
      }
    }
  },
  groups: [
    [0.89, 0.91, 0.88, 0.90, 0.92],  # Model A
    [0.87, 0.89, 0.86, 0.88, 0.90],  # Model B
    [0.84, 0.86, 0.83, 0.85, 0.87]   # Model C
  ]
}

{:ok, ctx} = CrucibleBench.Stage.run(context)
ctx.bench.tests.anova.effect_size.eta_squared
# => 0.72 (large effect)

# Paired comparison (paired t-test, Wilcoxon)
context = %{
  experiment: %{reliability: %{stats: stats_config}},
  before: [0.72, 0.68, 0.75, 0.71, 0.69],
  after: [0.78, 0.73, 0.81, 0.76, 0.74]
}

{:ok, ctx} = CrucibleBench.Stage.run(context)
# Automatically uses paired t-test
```

### Metrics Merging

The Stage automatically merges statistical results into `context.metrics`:

```elixir
{:ok, ctx} = CrucibleBench.Stage.run(context)

ctx.metrics.bench_n           # Sample size
ctx.metrics.bench_mean        # Mean value
ctx.metrics.bench_sd          # Standard deviation
ctx.metrics.bench_median      # Median value
ctx.metrics.bench_ttest_p_value  # P-value from t-test (if run)
```

This enables downstream pipeline stages to access statistical summaries directly.

## Inspect-AI Eval Logs

CrucibleBench can adapt EvalEx results into inspect-ai-style eval logs for downstream analysis:

```elixir
metrics = [
  %{accuracy: 1.0},
  %{accuracy: 0.0},
  %{accuracy: 1.0}
]

result = EvalEx.Result.new("inspect_evals/gsm8k", :testset, metrics, 3, 120)

log = CrucibleBench.EvalLog.from_eval_result(result, scorer_name: "llm_judge")

scores = CrucibleBench.EvalLog.Extract.eval_log_scores_dict(log)
stderr = CrucibleBench.EvalLog.Extract.eval_log_headline_stderr(log)
```

### Using IR Configuration

You can also pass `CrucibleIR.Reliability.Stats` directly to comparison functions:

```elixir
config = %CrucibleIR.Reliability.Stats{
  alpha: 0.01,
  confidence_level: 0.99,
  tests: [:ttest]
}

control = [0.72, 0.68, 0.75, 0.71, 0.69]
treatment = [0.78, 0.73, 0.81, 0.76, 0.74]

result = CrucibleBench.compare(control, treatment, config)
# Uses alpha=0.01 and 99% confidence interval
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
  labels: ["Config A", "Config B", "Config C"],
  correction_method: :holm # or :bonferroni, :benjamini_hochberg
)

# Identifies best configuration with pairwise comparisons
# Pairwise p-values are adjusted using the chosen correction method
```

## Assumption Checks (Normality & Variance)

```elixir
# Normality
NormalityTests.quick_check(data)          # fast skew/kurtosis screen
NormalityTests.assess_normality(data)     # Shapiro-Wilk + skew/kurtosis with recommendation

# Variance equality
VarianceTests.levene_test([g1, g2, g3])   # robust Brown-Forsythe (median-centered)
VarianceTests.f_test(g1, g2)              # classic F-test (assumes normality)
VarianceTests.quick_check(g1, g2)         # fast variance ratio heuristic
```

- Use normality/variance checks to choose between parametric and non-parametric tests.
- Constant or near-constant data is handled safely (no crashes).

## Multiple Comparison Control

```elixir
p_values = [0.01, 0.03, 0.04, 0.20]

# Adjust p-values
MultipleComparisons.correct(p_values, method: :holm)
MultipleComparisons.correct(p_values, method: :benjamini_hochberg, fdr_level: 0.10)

# Boolean rejections (uses the same alpha/FDR level)
MultipleComparisons.reject(p_values, method: :bonferroni)
```

- Hyperparameter sweeps automatically apply corrections (`:holm` default); set `correction_method:` and optional `fdr_level:` to change behavior.
- Exports include original and adjusted p-values plus significance under the chosen correction.

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
    ├── multiple_comparisons.ex       # p-value corrections (FWER/FDR)
    ├── normality_tests.ex            # Shapiro-Wilk + diagnostics
    ├── variance_tests.ex             # Levene, F-test, variance heuristics
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

## Advanced Features

### Bootstrap Confidence Intervals

For small samples or non-normal data, use bootstrap methods:

```elixir
# Bootstrap CI for median (robust to outliers)
data = [0.85, 0.87, 0.84, 0.86, 0.88, 0.83, 0.89, 0.85]
ci = CrucibleBench.confidence_interval(data, :median,
  method: :bootstrap,
  iterations: 10000
)
# => %{interval: {0.835, 0.875}, method: :bootstrap, bootstrap_distribution: %{...}}
```

### Multiple Effect Size Measures

```elixir
# Compare different effect size calculations
cohens_d = Stats.EffectSize.cohens_d(group1, group2)
hedges_g = Stats.EffectSize.hedges_g(group1, group2)  # Bias-corrected
glass_delta = Stats.EffectSize.glass_delta(group1, group2)  # Control SD only

IO.puts("Cohen's d: #{cohens_d.cohens_d}")
IO.puts("Hedges' g: #{hedges_g.hedges_g}")
IO.puts("Glass's Δ: #{glass_delta.glass_delta}")
```

### Power Analysis Curves

Calculate power for different sample sizes:

```elixir
effect_size = 0.5
for n <- [20, 30, 50, 100] do
  power = CrucibleBench.power_analysis(:t_test,
    analysis_type: :post_hoc,
    effect_size: effect_size,
    n_per_group: n,
    alpha: 0.05
  )
  IO.puts("n=#{n}: power=#{Float.round(power.power * 100, 1)}%")
end
```

## Complete API Reference

### Core Functions

#### `CrucibleBench.compare(group1, group2, opts \\\\ [])`

Compares two independent groups with automatic test selection.

**Options:**
- `:test` - Force specific test (`:t_test`, `:welch_t_test`, `:mann_whitney`)
- `:confidence_level` - CI level (default: 0.95)
- `:check_assumptions` - Test normality (default: true)
- `:alternative` - `:two_sided`, `:less`, `:greater`

**Returns:** `CrucibleBench.Result` struct

#### `CrucibleBench.compare_paired(group1, group2, opts \\\\ [])`

Compares paired/related groups.

**Options:** Same as `compare/3`

#### `CrucibleBench.compare_multiple(groups, opts \\\\ [])`

Compares 3+ groups with ANOVA or Kruskal-Wallis.

**Options:**
- `:test` - Force `:anova` or `:kruskal_wallis`
- `:check_assumptions` - Test normality (default: true)

#### `CrucibleBench.effect_size(group1, group2, opts \\\\ [])`

Calculates Cohen's d effect size.

#### `CrucibleBench.confidence_interval(data, statistic, opts \\\\ [])`

Calculates confidence intervals.

**Statistics:** `:mean`, `:median`, `:variance`, etc.
**Methods:** `:analytical`, `:bootstrap`

#### `CrucibleBench.power_analysis(test_type, opts \\\\ [])`

Power analysis calculations.

**Types:** `:a_priori`, `:post_hoc`
**Required:** `:effect_size`, `:alpha`, `:power` or `:n_per_group`

### Experiment DSL

#### `CrucibleBench.experiment(:ab_test, opts)`

**Options:**
- `:control` - Control group data
- `:treatment` - Treatment group data
- `:name` - Experiment name

#### `CrucibleBench.experiment(:ablation, opts)`

**Options:**
- `:baseline` - Full system performance
- `:without_component` - Performance without component
- `:component_name` - Name of removed component

#### `CrucibleBench.experiment(:hyperparameter_sweep, opts)`

**Options:**
- `:configurations` - List of performance arrays
- `:labels` - Configuration names

### Export Functions

#### `CrucibleBench.Export.to_markdown(result)`

#### `CrucibleBench.Export.to_latex(result)`

#### `CrucibleBench.Export.to_html(result)`

#### `CrucibleBench.Export.experiment_to_markdown(experiment_result)`

## Integration Examples

### With Phoenix LiveView

```elixir
defmodule StatsLive do
  use Phoenix.LiveView

  def handle_event("run_test", %{"control" => control, "treatment" => treatment}, socket) do
    result = CrucibleBench.compare(control, treatment)
    markdown = CrucibleBench.Export.to_markdown(result)

    {:noreply, assign(socket, result: result, markdown: markdown)}
  end
end
```

### Research Workflow Integration

```elixir
defmodule ResearchPipeline do
  def run_experiment(control_data, treatment_data, metadata) do
    # 1. Run statistical test
    result = CrucibleBench.compare(control_data, treatment_data)

    # 2. Check power
    power_analysis = CrucibleBench.power_analysis(:t_test,
      analysis_type: :post_hoc,
      effect_size: abs(result.effect_size.cohens_d),
      n_per_group: length(control_data),
      alpha: 0.05
    )

    # 3. Generate report
    report = CrucibleBench.Export.experiment_to_markdown(%{
      experiment_type: :ab_test,
      name: metadata.name,
      significant?: result.p_value < 0.05,
      p_value: result.p_value,
      effect_size: result.effect_size,
      power: power_analysis.power,
      # ... other fields
    })

    # 4. Save results
    File.write!("results/#{metadata.name}.md", report)

    {:ok, result, power_analysis}
  end
end
```

### Benchmark Integration

```elixir
defmodule BenchmarkRunner do
  def run_benchmarks(models, dataset) do
    results = for {name, model} <- models do
      scores = Enum.map(dataset, &model.predict/1)
      {name, scores}
    end

    # Statistical comparison of all models
    score_lists = Enum.map(results, fn {_name, scores} -> scores end)
    comparison = CrucibleBench.compare_multiple(score_lists)

    # Pairwise comparisons
    pairwise = for i <- 0..(length(results)-2),
                   j <- (i+1)..(length(results)-1) do
      {name_i, scores_i} = Enum.at(results, i)
      {name_j, scores_j} = Enum.at(results, j)

      result = CrucibleBench.compare(scores_i, scores_j)
      %{comparison: "#{name_i} vs #{name_j}",
        p_value: result.p_value,
        effect_size: result.effect_size.cohens_d}
    end

    %{omnibus: comparison, pairwise: pairwise}
  end
end
```

## Performance Considerations

### Memory Usage

- Bootstrap methods with high iteration counts (>10,000) may consume significant memory
- For large datasets, consider using analytical methods when assumptions are met
- Effect size calculations are O(n) in sample size

### Computational Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| t-test | O(n) | Fast for any n |
| ANOVA | O(k×n) | k = number of groups |
| Bootstrap CI | O(iterations × n) | Expensive for high precision |
| Mann-Whitney | O(n²) | Slow for large n (>1000) |
| Kruskal-Wallis | O(n log n) | Better scaling |

### Optimization Tips

```elixir
# Use analytical methods when possible
ci = CrucibleBench.confidence_interval(data, :mean, method: :analytical)

# Reduce bootstrap iterations for faster results
ci = CrucibleBench.confidence_interval(data, :median,
  method: :bootstrap,
  iterations: 1000  # Instead of default 10000
)

# Cache results for repeated analyses
@cached_power_analysis Memoize.memoize fn params ->
  CrucibleBench.power_analysis(params)
end
```

## Troubleshooting

### Common Issues

#### Non-significant results despite large differences

```elixir
# Check if you have enough power
result = CrucibleBench.compare(group1, group2)
power = CrucibleBench.power_analysis(:t_test,
  analysis_type: :post_hoc,
  effect_size: abs(result.effect_size.cohens_d),
  n_per_group: length(group1),
  alpha: 0.05
)

if power.power < 0.8 do
  IO.puts("Underpowered study! Need larger sample size.")
end
```

#### Assumption violations

```elixir
# Check normality
result = CrucibleBench.compare(group1, group2, check_assumptions: true)
# If normality test fails, consider non-parametric tests

# Or manually check
skew1 = CrucibleBench.Stats.skewness(group1)
kurt1 = CrucibleBench.Stats.kurtosis(group1)
```

#### Outliers affecting results

```elixir
# Use robust statistics
median_ci = CrucibleBench.confidence_interval(data, :median, method: :bootstrap)
# Compare with mean-based results
```

### Error Messages

- **"Need at least 2 groups"**: `compare_multiple/2` requires 2+ groups
- **"Unknown test: xyz"**: Invalid test type specified
- **"Sample size too small"**: Some tests require minimum n (e.g., normality tests)

## Research Methodology

### Best Practices Checklist

- [ ] **Power Analysis**: Calculate required sample size before data collection
- [ ] **Effect Sizes**: Always report alongside p-values
- [ ] **Assumptions**: Test normality, homogeneity of variance
- [ ] **Multiple Testing**: Apply corrections for multiple comparisons
- [ ] **Confidence Intervals**: Report CIs, not just p-values
- [ ] **Replication**: Design studies for reproducibility

### Common Research Scenarios

#### Pre-registered Analysis Plan

```elixir
# Define analysis plan before data collection
analysis_plan = %{
  primary_test: :welch_t_test,
  alpha: 0.05,
  power_target: 0.80,
  effect_size_estimate: 0.5,
  required_n: 64  # From a priori power analysis
}

# Execute plan
result = CrucibleBench.compare(group1, group2, test: analysis_plan.primary_test)
```

#### Exploratory Data Analysis

```elixir
# Multiple effect sizes for robustness
effect_sizes = [
  CrucibleBench.effect_size(group1, group2),
  Stats.EffectSize.hedges_g(group1, group2),
  Stats.EffectSize.glass_delta(group1, group2)
]

# Sensitivity analysis with different tests
results = [
  CrucibleBench.compare(group1, group2, test: :welch_t_test),
  CrucibleBench.compare(group1, group2, test: :mann_whitney)
]
```

#### Meta-analysis Preparation

```elixir
# Calculate effect sizes for meta-analysis
studies = [
  {study1_control, study1_treatment, "Study 1"},
  {study2_control, study2_treatment, "Study 2"}
]

meta_data = for {control, treatment, name} <- studies do
  effect = CrucibleBench.effect_size(control, treatment)
  result = CrucibleBench.compare(control, treatment)

  %{
    study: name,
    cohens_d: effect.cohens_d,
    variance: Stats.effect_size_variance(effect.cohens_d, length(control) + length(treatment)),
    n: length(control) + length(treatment)
  }
end
```

## Contributing

### Development Setup

```bash
# Clone and setup
git clone https://github.com/North-Shore-AI/crucible_bench.git
cd crucible_bench
mix deps.get

# Run tests
mix test

# Run examples
mix run examples/basic_usage.exs
mix run examples/advanced_usage.exs

# Generate docs
mix docs
```

### Code Standards

- **Modules**: Follow Elixir naming conventions
- **Functions**: Clear, descriptive names with comprehensive documentation
- **Tests**: Unit tests for all public functions, property-based tests where applicable
- **Documentation**: Complete `@doc` and `@moduledoc` with examples

### Adding New Tests

```elixir
# 1. Implement test in appropriate stats module
defmodule CrucibleBench.Stats.NewTest do
  def test(group1, group2, opts \\ []) do
    # Implementation
    # Return CrucibleBench.Result struct
  end
end

# 2. Add to Analysis module
def compare_groups(group1, group2, opts) do
  # ... existing logic
  test_to_use = if new_condition, do: :new_test, else: existing_logic

  case test_to_use do
    :new_test -> NewTest.test(group1, group2, opts)
    # ... other cases
  end
end

# 3. Add comprehensive tests
test "new test handles various inputs" do
  # Test cases
end
```

### Reporting Issues

Please include:
- Elixir/Erlang versions
- Sample data that reproduces the issue
- Expected vs actual behavior
- Full error messages and stack traces

## License

MIT License - see [LICENSE](https://github.com/North-Shore-AI/crucible_bench/blob/main/LICENSE) file for details

## Changelog

### v0.2.0 (Current)
- Complete statistical testing framework with parametric and non-parametric coverage using accurate distribution functions
- Expanded effect size suite with paired measures, eta/omega squared, and rank-biserial correlation plus interpretation guidance
- Analytical and bootstrap confidence intervals and power analysis with actionable recommendations
- High-level helpers for automatic test selection and experiment DSL for A/B tests, ablations, and hyperparameter sweeps
- Publication-ready exports to Markdown, LaTeX, and HTML with standardized result metadata

### v0.1.0
- Initial release with comprehensive statistical testing framework
- Support for parametric and non-parametric tests
- Effect size calculations and power analysis
- Bootstrap confidence intervals
- Experiment DSL for common research patterns
- Export to Markdown, LaTeX, and HTML formats
- Complete documentation and examples
