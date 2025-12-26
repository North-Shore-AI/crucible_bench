# CrucibleBench Gap Analysis

**Generated**: 2025-12-25
**Version Analyzed**: 0.3.1

## Critical Gaps

### 1. No Formal `@behaviour Crucible.Stage` Declaration

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`

**Issue**: The Stage module implements `run/2` and `describe/1` functions matching the Crucible.Stage behaviour, but does not formally declare the behaviour. This means:
- No compile-time checking that the interface is correctly implemented
- No documentation linking to the behaviour
- Potential runtime errors if interface drifts

**Current Code** (lines 41-43):
```elixir
# Note: We define the callback functions but don't use @behaviour since
# crucible_framework may not be a dependency. The framework will call these
# functions dynamically.
```

**Recommendation**: Add optional behaviour declaration:
```elixir
if Code.ensure_loaded?(Crucible.Stage) do
  @behaviour Crucible.Stage
end
```

### 2. Stage Does Not Merge Results into Metrics

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`

**Issue**: The Stage puts results under `:bench` key but does not merge statistical results into `context.metrics` as expected by the pipeline pattern.

**Current Code** (lines 69-71):
```elixir
{:ok, Map.put(context, :bench, results)}
```

**Should Also**:
- Extract key metrics (mean, std, p_value, effect_size) into `context.metrics`
- This enables downstream stages to access statistical summaries

### 3. Limited Two-Group Test Support in Stage

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`

**Issue**: The Stage currently only handles single-group data. For tests like t-test and ANOVA that require multiple groups, it returns placeholder notes instead of actual test results.

**Current Code** (lines 224-233):
```elixir
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
```

**Missing**:
- Support for `context.control` and `context.treatment` groups
- Support for `context.groups` list for ANOVA/Kruskal-Wallis
- Baseline comparison for single-group t-tests (compare against hypothesized mean)

### 4. Missing Dialyzer/Credo Configuration Verification

**Location**: `mix.exs`

**Issue**: While dialyzer is configured, need to verify:
- All functions have proper typespecs
- No dialyzer warnings
- Credo passes with --strict

## Moderate Gaps

### 5. Stage Missing Typespecs

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`

**Issue**: No `@spec` declarations for public functions.

**Missing**:
```elixir
@spec run(map(), map()) :: {:ok, map()} | {:error, String.t()}
@spec describe(map()) :: map()
```

### 6. No One-Sample T-Test

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/`

**Issue**: No implementation for one-sample t-test (compare sample mean against known population mean). This is useful for comparing against baseline performance.

### 7. F-Distribution P-Value Approximation is Crude

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/variance_tests.ex`

**Issue** (lines 239-262):
```elixir
defp approximate_f_p_value(f, _df1, _df2) do
  cond do
    f == :infinity -> 0.0
    f > 20 -> 0.001
    f > 10 -> 0.01
    f > 5 -> 0.05
    ...
  end
end
```

This approximation is very rough and ignores degrees of freedom. Should use proper F-distribution CDF from `Distributions` module.

### 8. Limited Error Messages

**Location**: Multiple modules

**Issue**: Error messages could be more descriptive with suggestions for resolution.

Example from Stage (line 118):
```elixir
{:error, "Missing experiment.reliability.stats configuration"}
```

**Better**:
```elixir
{:error, "Missing experiment.reliability.stats configuration. " <>
         "Expected CrucibleIR.Reliability.Stats struct at context.experiment.reliability.stats"}
```

### 9. Missing Welch's ANOVA

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/anova.ex`

**Issue**: Only standard one-way ANOVA is implemented. Welch's ANOVA would handle heterogeneous variances better.

### 10. No Repeated Measures ANOVA

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/`

**Issue**: No support for within-subjects designs common in ML experiments (e.g., same model tested on multiple datasets).

## Minor Gaps

### 11. Bootstrap Seed Handling

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/confidence_interval.ex`

**Issue** (lines 110-113):
```elixir
seed = Keyword.get(opts, :seed, :os.system_time(:microsecond))
:rand.seed(:exsplus, {seed, seed + 1, seed + 2})
```

Using `:exsplus` is deprecated. Should use `:exsss` or `:exrop`.

### 12. Missing Doctest Coverage

**Location**: Multiple modules

**Issue**: Some modules lack comprehensive doctests. For example, `Stage` module has no doctests.

### 13. No JSON Export

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/export.ex`

**Issue**: Only Markdown, LaTeX, and HTML exports are available. JSON export would be useful for programmatic consumption.

### 14. Stage Doesn't Support Streaming Data

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`

**Issue**: Stage expects all data upfront. No support for incremental/streaming statistical updates.

### 15. README Not Updated for Stage

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/README.md`

**Issue**: The README documents Stage usage but could be enhanced with:
- More detailed integration examples with crucible_framework
- Configuration options table
- Error handling examples

## Documentation Gaps

### 16. No Architecture Diagram

**Issue**: No visual representation of module relationships.

### 17. Missing Changelog for Stage Integration

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/CHANGELOG.md`

**Issue**: Stage was added but changelog mentions v0.2.0. Need v0.3.1 changelog entry.

### 18. No Contributing Guide

**Issue**: No CONTRIBUTING.md with code style, testing requirements, PR process.

## Testing Gaps

### 19. Stage Test Coverage Could Be Expanded

**Location**: `/home/home/p/g/North-Shore-AI/crucible_bench/test/crucible_bench/stage_test.exs`

**Missing Tests**:
- Test with actual t-test requiring two groups
- Test with ANOVA requiring multiple groups
- Test error handling for malformed data
- Test with very large datasets
- Property-based tests for numeric stability

### 20. No Integration Tests with crucible_framework

**Issue**: Stage is tested in isolation but no tests verify it works correctly within an actual crucible_framework pipeline.

## Priority Ranking

1. **High**: #1, #2, #3 - Stage behaviour and functionality
2. **High**: #4, #5 - Code quality (dialyzer, typespecs)
3. **Medium**: #6, #7 - Statistical test completeness
4. **Medium**: #15, #17 - Documentation
5. **Low**: #11-14 - Nice-to-haves
