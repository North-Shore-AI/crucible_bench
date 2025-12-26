# CrucibleBench Current State Documentation

**Version**: 0.3.1
**Generated**: 2025-12-25
**Repository**: https://github.com/North-Shore-AI/crucible_bench

## Overview

CrucibleBench is a comprehensive statistical testing framework designed for AI/ML research in Elixir. It provides rigorous statistical tests, effect size measures, power analysis, and publication-ready reporting.

## Architecture

```
lib/
├── bench.ex                           # Main API module (CrucibleBench)
└── crucible_bench/
    ├── analysis.ex                    # High-level analysis with auto test selection
    ├── experiment.ex                  # Experiment DSL (A/B, ablation, sweep)
    ├── export.ex                      # Export to Markdown/LaTeX/HTML
    ├── result.ex                      # Result struct definition
    ├── stage.ex                       # Pipeline stage for crucible_framework
    ├── stats.ex                       # Core statistics (mean, variance, etc.)
    ├── eval_log.ex                    # Inspect-AI compatible eval logs
    ├── eval_log/
    │   └── extract.ex                 # EvalLog extraction helpers
    └── stats/
        ├── t_test.ex                  # Independent t-test (Student's/Welch's)
        ├── paired_t_test.ex           # Paired samples t-test
        ├── anova.ex                   # One-way ANOVA
        ├── mann_whitney.ex            # Mann-Whitney U test
        ├── wilcoxon.ex                # Wilcoxon signed-rank test
        ├── kruskal_wallis.ex          # Kruskal-Wallis H test
        ├── effect_size.ex             # Cohen's d, Hedges' g, Glass's delta
        ├── confidence_interval.ex     # Analytical and bootstrap CIs
        ├── power.ex                   # A priori and post-hoc power analysis
        ├── distributions.ex           # Probability distributions (t, F, chi-sq)
        ├── multiple_comparisons.ex    # Bonferroni, Holm, BH corrections
        ├── normality_tests.ex         # Shapiro-Wilk and diagnostics
        └── variance_tests.ex          # Levene's test, F-test
```

## Module Details

### Main API: `CrucibleBench` (lib/bench.ex)

**Lines**: 1-253

The main entry point providing high-level functions:

| Function | Line | Description |
|----------|------|-------------|
| `compare/3` | 78-88 | Compare two independent groups |
| `compare_paired/3` | 103-105 | Compare paired/related groups |
| `compare_multiple/2` | 122-124 | Compare 3+ groups with ANOVA/Kruskal-Wallis |
| `effect_size/3` | 139-141 | Calculate effect size (Cohen's d) |
| `confidence_interval/3` | 162-164 | Calculate confidence intervals |
| `power_analysis/2` | 186-188 | A priori or post-hoc power analysis |
| `experiment/2` | 211-213 | High-level experiment DSL |

**Key Integration**: Accepts `CrucibleIR.Reliability.Stats` structs directly for configuration.

### Analysis: `CrucibleBench.Analysis` (lib/crucible_bench/analysis.ex)

**Lines**: 1-169

Automatic test selection based on data characteristics:

| Function | Line | Description |
|----------|------|-------------|
| `compare_groups/3` | 35-68 | Auto-selects t-test or Mann-Whitney |
| `compare_paired/3` | 75-109 | Auto-selects paired t-test or Wilcoxon |
| `compare_multiple/2` | 117-141 | Auto-selects ANOVA or Kruskal-Wallis |
| `normal_enough?/1` | 144-159 | Normality check using skewness/kurtosis |

### Result Struct: `CrucibleBench.Result` (lib/crucible_bench/result.ex)

**Lines**: 1-83

Standard result structure returned by all tests:

```elixir
%CrucibleBench.Result{
  test: atom(),           # Test type used
  statistic: float(),     # Test statistic value
  p_value: float(),       # P-value
  effect_size: map(),     # Effect size measure
  confidence_interval: {float(), float()},  # CI tuple
  interpretation: String.t(),  # Human-readable interpretation
  metadata: map()         # Additional test-specific data
}
```

| Function | Line | Description |
|----------|------|-------------|
| `significant?/2` | 42-44 | Check if result is significant at alpha |
| `summarize/1` | 49-74 | Generate human-readable summary |

### Stage: `CrucibleBench.Stage` (lib/crucible_bench/stage.ex)

**Lines**: 1-277

Pipeline stage for integration with crucible_framework:

| Function | Line | Description |
|----------|------|-------------|
| `run/2` | 65-71 | Run statistical analysis on context |
| `describe/1` | 83-108 | Return stage metadata |

**Context Requirements**:
- `experiment.reliability.stats` - CrucibleIR.Reliability.Stats configuration
- `outputs` or `metrics` - Data to analyze

**Note**: Does NOT use `@behaviour Crucible.Stage` due to optional dependency.

### Statistical Tests

#### T-Tests

**`CrucibleBench.Stats.TTest`** (lib/crucible_bench/stats/t_test.ex)
- Lines: 1-140
- `test/3` (line 32): Independent samples t-test with Welch correction

**`CrucibleBench.Stats.PairedTTest`** (lib/crucible_bench/stats/paired_t_test.ex)
- Lines: 1-94
- `test/3` (line 28): Paired samples t-test

#### ANOVA

**`CrucibleBench.Stats.ANOVA`** (lib/crucible_bench/stats/anova.ex)
- Lines: 1-135
- `one_way/2` (line 29): One-way ANOVA with eta-squared and omega-squared

#### Non-Parametric Tests

**`CrucibleBench.Stats.MannWhitney`** (lib/crucible_bench/stats/mann_whitney.ex)
- Lines: 1-145
- `test/3` (line 27): Mann-Whitney U test with rank-biserial correlation

**`CrucibleBench.Stats.Wilcoxon`** (lib/crucible_bench/stats/wilcoxon.ex)
- Lines: 1-142
- `test/3` (line 27): Wilcoxon signed-rank test

**`CrucibleBench.Stats.KruskalWallis`** (lib/crucible_bench/stats/kruskal_wallis.ex)
- Lines: 1-128
- `test/2` (line 28): Kruskal-Wallis H test with epsilon-squared

### Effect Sizes

**`CrucibleBench.Stats.EffectSize`** (lib/crucible_bench/stats/effect_size.ex)
- Lines: 1-217

| Function | Line | Description |
|----------|------|-------------|
| `cohens_d/2` | 36-54 | Cohen's d for independent groups |
| `hedges_g/2` | 70-89 | Bias-corrected Cohen's d |
| `glass_delta/2` | 111-130 | Effect size using control SD only |
| `paired_cohens_d/2` | 146-173 | Cohen's d for paired data |
| `calculate/3` | 191-205 | General calculation with options |

### Confidence Intervals

**`CrucibleBench.Stats.ConfidenceInterval`** (lib/crucible_bench/stats/confidence_interval.ex)
- Lines: 1-171

| Function | Line | Description |
|----------|------|-------------|
| `calculate/3` | 29-37 | Calculate CI (analytical or bootstrap) |
| `analytical_ci/3` | 45-94 | Analytical CI for mean/variance |
| `bootstrap_ci/3` | 107-147 | Bootstrap percentile CI |

### Power Analysis

**`CrucibleBench.Stats.Power`** (lib/crucible_bench/stats/power.ex)
- Lines: 1-229

| Function | Line | Description |
|----------|------|-------------|
| `analyze/2` | 42-52 | Main power analysis entry point |
| `t_test_sample_size/1` | 59-86 | A priori sample size for t-test |
| `t_test_power/1` | 91-129 | Post-hoc power for t-test |
| `anova_sample_size/1` | 134-165 | A priori sample size for ANOVA |
| `anova_power/1` | 170-216 | Post-hoc power for ANOVA |

### Multiple Comparisons

**`CrucibleBench.Stats.MultipleComparisons`** (lib/crucible_bench/stats/multiple_comparisons.ex)
- Lines: 1-271

| Function | Line | Description |
|----------|------|-------------|
| `bonferroni/1` | 43-51 | Bonferroni correction |
| `holm/1` | 71-98 | Holm step-down method |
| `benjamini_hochberg/2` | 127-165 | Benjamini-Hochberg FDR |
| `correct/2` | 190-220 | Apply correction with detailed results |
| `reject/2` | 256-270 | Get boolean rejection decisions |

### Assumption Tests

**`CrucibleBench.Stats.NormalityTests`** (lib/crucible_bench/stats/normality_tests.ex)
- Lines: 1-353

| Function | Line | Description |
|----------|------|-------------|
| `shapiro_wilk/1` | 46-59 | Shapiro-Wilk test for normality |
| `assess_normality/2` | 239-301 | Comprehensive normality assessment |
| `quick_check/1` | 315-352 | Fast skewness/kurtosis check |

**`CrucibleBench.Stats.VarianceTests`** (lib/crucible_bench/stats/variance_tests.ex)
- Lines: 1-313

| Function | Line | Description |
|----------|------|-------------|
| `levene_test/2` | 44-81 | Levene's test (Brown-Forsythe variant) |
| `f_test/2` | 97-165 | Classical F-test for two groups |
| `quick_check/2` | 291-312 | Fast variance ratio heuristic |

### Distributions

**`CrucibleBench.Stats.Distributions`** (lib/crucible_bench/stats/distributions.ex)
- Lines: 1-344

| Function | Line | Description |
|----------|------|-------------|
| `normal_cdf/3` | 13-16 | Standard normal CDF |
| `normal_quantile/1` | 23-78 | Inverse normal CDF |
| `t_cdf/2` | 85-93 | Student's t CDF |
| `t_quantile/2` | 101-148 | Student's t inverse CDF |
| `f_cdf/3` | 155-158 | F-distribution CDF |
| `chi_squared_cdf/2` | 165-167 | Chi-squared CDF |

### Core Statistics

**`CrucibleBench.Stats`** (lib/crucible_bench/stats.ex)
- Lines: 1-293

| Function | Line | Description |
|----------|------|-------------|
| `mean/1` | 16-20 | Arithmetic mean |
| `median/1` | 33-45 | Median value |
| `variance/2` | 60-75 | Sample/population variance |
| `stdev/2` | 85-90 | Standard deviation |
| `sem/1` | 100-106 | Standard error of mean |
| `quantile/2` | 116-133 | Quantile at probability p |
| `z_scores/1` | 143-155 | Z-score standardization |
| `skewness/1` | 163-182 | Distribution skewness |
| `kurtosis/1` | 190-213 | Distribution kurtosis |
| `correlation/2` | 227-260 | Pearson correlation |
| `rank/1` | 270-292 | Rank values with tie handling |

### Experiment DSL

**`CrucibleBench.Experiment`** (lib/crucible_bench/experiment.ex)
- Lines: 1-259

| Function | Line | Description |
|----------|------|-------------|
| `run(:ab_test, opts)` | 35-78 | A/B test analysis |
| `run(:ablation, opts)` | 80-115 | Ablation study |
| `run(:hyperparameter_sweep, opts)` | 117-157 | Hyperparameter comparison |

### Export

**`CrucibleBench.Export`** (lib/crucible_bench/export.ex)
- Lines: 1-388

| Function | Line | Description |
|----------|------|-------------|
| `to_markdown/1` | 25-44 | Export result to Markdown |
| `to_latex/1` | 51-69 | Export result to LaTeX table |
| `to_html/1` | 76-119 | Export result to styled HTML |
| `experiment_to_markdown/1` | 124-129 | Export experiment to report |

### EvalLog Integration

**`CrucibleBench.EvalLog`** (lib/crucible_bench/eval_log.ex)
- Lines: 1-199

Provides Inspect-AI compatible evaluation log schema:
- `EvalMetric`, `EvalScore`, `EvalResults`, `EvalDataset`, `EvalSpec`, `EvalStats` structs
- `from_eval_result/2` (line 120): Build EvalLog from EvalEx.Result

**`CrucibleBench.EvalLog.Extract`** (lib/crucible_bench/eval_log/extract.ex)
- Lines: 1-64

| Function | Line | Description |
|----------|------|-------------|
| `eval_log_location/1` | 11 | Get log location |
| `eval_log_task_display_name/1` | 16-21 | Get task display name |
| `eval_log_scores_dict/1` | 26-37 | Extract scores as dict |
| `eval_log_headline_stderr/1` | 42-55 | Extract headline stderr |

## Dependencies

From `mix.exs`:
- `statistex ~> 1.0` - Statistical utilities
- `nx ~> 0.7` - Numerical computing
- `crucible_ir ~> 0.1.1` - Experiment IR definitions
- `eval_ex ~> 0.1.2` - Evaluation framework

## Test Coverage

Test files in `test/`:
- `bench_test.exs` - Main API tests
- `stats_test.exs` - Core statistics tests
- `effect_size_test.exs` - Effect size tests
- `normality_tests_test.exs` - Normality test tests
- `multiple_comparisons_test.exs` - Multiple comparison tests
- `variance_tests_test.exs` - Variance test tests
- `eval_log_test.exs` - EvalLog integration tests
- `crucible_bench/stage_test.exs` - Stage tests

## Integration Points

### CrucibleIR.Reliability.Stats

The Stage accepts this configuration struct:
```elixir
%CrucibleIR.Reliability.Stats{
  tests: [:ttest, :bootstrap, :anova, ...],
  alpha: 0.05,
  confidence_level: 0.95,
  effect_size_type: :cohens_d,
  multiple_testing_correction: :bonferroni,
  bootstrap_iterations: 1000,
  options: %{}
}
```

### crucible_framework Integration

The `CrucibleBench.Stage` module provides pipeline integration but does NOT declare `@behaviour Crucible.Stage` because crucible_framework is not a direct dependency. The module implements the expected interface:

```elixir
@callback run(context :: map(), opts :: map()) ::
            {:ok, map()} | {:error, term()}

@callback describe(opts :: map()) :: map()
```
