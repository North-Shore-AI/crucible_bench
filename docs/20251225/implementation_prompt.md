# Implementation Prompt: CrucibleBench Stage Enhancement

## Task Overview

Enhance `CrucibleBench.Stage` to properly implement the `Crucible.Stage` behaviour from crucible_framework, with full support for multi-group statistical tests and proper metrics merging.

## Required Reading

Before starting, thoroughly read these files:

### Core Files to Read

1. **Stage Behaviour Definition**:
   - `/home/home/p/g/North-Shore-AI/crucible_framework/lib/crucible/stage.ex` (19 lines)
   - Defines: `run/2` and `describe/1` callbacks

2. **Current Stage Implementation**:
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex` (277 lines)
   - Key functions:
     - `run/2` at line 65
     - `describe/1` at line 83
     - `extract_stats_config/1` at line 112
     - `extract_data/2` at line 125
     - `run_tests/3` at line 173
     - `execute_test/3` at lines 224-276

3. **CrucibleIR Configuration**:
   - `/home/home/p/g/North-Shore-AI/crucible_ir/lib/crucible_ir/reliability/stats.ex`
   - Defines `CrucibleIR.Reliability.Stats` struct

4. **Existing Stage Tests**:
   - `/home/home/p/g/North-Shore-AI/crucible_bench/test/crucible_bench/stage_test.exs` (283 lines)

5. **Main API Module**:
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/bench.ex` (253 lines)
   - Shows how to use Analysis functions

6. **Analysis Module** (for actual test execution):
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/analysis.ex` (169 lines)
   - `compare_groups/3` at line 35
   - `compare_paired/3` at line 75
   - `compare_multiple/2` at line 117

7. **Statistical Test Modules**:
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/t_test.ex` (140 lines)
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/anova.ex` (135 lines)
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stats/mann_whitney.ex` (145 lines)

8. **Result Struct**:
   - `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/result.ex` (83 lines)

9. **Mix Configuration**:
   - `/home/home/p/g/North-Shore-AI/crucible_bench/mix.exs` (115 lines)
   - Dependencies and dialyzer config

10. **README**:
    - `/home/home/p/g/North-Shore-AI/crucible_bench/README.md` (1006 lines)
    - Current Stage documentation at lines 55-87

## Current Stage Module Structure

```elixir
# /home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex

defmodule CrucibleBench.Stage do
  # Line 1-37: Moduledoc with example

  # Line 39-43: Note about not using @behaviour

  # Line 45-71: run/2 - Main entry point
  #   - Extracts stats config
  #   - Extracts data
  #   - Runs tests
  #   - Returns {:ok, context} with :bench key added

  # Line 83-108: describe/1 - Stage metadata

  # Line 112-122: extract_stats_config/1 - Gets CrucibleIR.Reliability.Stats

  # Line 125-139: extract_data/2 - Gets data from :outputs or :metrics

  # Line 141-170: validate_data/1, extract_numeric_values/1

  # Line 173-209: run_tests/3 - Orchestrates test execution

  # Line 211-221: build_test_opts/2 - Builds options from config

  # Line 224-276: execute_test/3 clauses for each test type
  #   - :ttest (224-233) - PLACEHOLDER, just returns note
  #   - :bootstrap (236-254) - Actually works
  #   - :anova (256-263) - PLACEHOLDER
  #   - :mannwhitney, :wilcoxon, :kruskal (265-272) - PLACEHOLDER
  #   - Unknown (274-276)
end
```

## Implementation Requirements

### 1. Add @behaviour Declaration (Conditional)

At the top of the Stage module (after `alias CrucibleBench.Stats`), add:

```elixir
# Conditionally use behaviour if crucible_framework is available
if Code.ensure_loaded?(Crucible.Stage) do
  @behaviour Crucible.Stage
end
```

### 2. Add Type Specifications

Add these specs to the Stage module:

```elixir
@type context :: map()
@type opts :: map()
@type error_reason :: String.t()

@spec run(context(), opts()) :: {:ok, context()} | {:error, error_reason()}
@spec describe(opts()) :: map()
```

### 3. Support Multi-Group Data Extraction

Modify `extract_data/2` to handle:
- Single group: `context.outputs` or `context.metrics` (current behavior)
- Two groups: `context.control` and `context.treatment`
- Multiple groups: `context.groups` (list of lists)
- Paired groups: `context.before` and `context.after`

New function signature:
```elixir
@spec extract_data(context(), opts()) ::
  {:ok, {:single, [number()]}} |
  {:ok, {:paired, [number()], [number()]}} |
  {:ok, {:two_groups, [number()], [number()]}} |
  {:ok, {:multiple_groups, [[number()]]}} |
  {:error, String.t()}
```

### 4. Implement Actual Statistical Tests

Replace placeholder `execute_test/3` implementations:

#### T-Test (Two Groups)
```elixir
defp execute_test(:ttest, {:two_groups, group1, group2}, opts) do
  alpha = Keyword.get(opts, :alpha, 0.05)
  result = CrucibleBench.Stats.TTest.test(group1, group2)
  effect = CrucibleBench.Stats.EffectSize.cohens_d(group1, group2)

  {:ok, %{
    test_type: :ttest,
    statistic: result.statistic,
    p_value: result.p_value,
    significant: result.p_value < alpha,
    effect_size: effect,
    confidence_interval: result.confidence_interval,
    interpretation: result.interpretation
  }}
end

defp execute_test(:ttest, {:single, data}, opts) do
  # One-sample t-test against mu=0 or opts[:mu]
  mu = Keyword.get(opts, :mu, 0.0)
  # ... implement one-sample t-test
end
```

#### ANOVA (Multiple Groups)
```elixir
defp execute_test(:anova, {:multiple_groups, groups}, opts) do
  alpha = Keyword.get(opts, :alpha, 0.05)
  result = CrucibleBench.Stats.ANOVA.one_way(groups)

  {:ok, %{
    test_type: :anova,
    statistic: result.statistic,
    p_value: result.p_value,
    significant: result.p_value < alpha,
    effect_size: result.effect_size,
    interpretation: result.interpretation
  }}
end
```

### 5. Merge Results into Metrics

Modify `run/2` to merge key statistics into `context.metrics`:

```elixir
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

    # Add test-specific metrics
    bench_metrics =
      Enum.reduce(results.tests, bench_metrics, fn {test_name, test_result}, acc ->
        if Map.has_key?(test_result, :p_value) do
          Map.put(acc, :"bench_#{test_name}_p_value", test_result.p_value)
        else
          acc
        end
      end)

    # Merge into existing metrics
    updated_metrics = Map.merge(Map.get(context, :metrics, %{}), bench_metrics)

    context
    |> Map.put(:bench, results)
    |> Map.put(:metrics, updated_metrics)
    |> then(&{:ok, &1})
  end
end
```

### 6. Update README.md

Add a new section after the existing Pipeline Integration section:

```markdown
### Advanced Stage Configuration

The Stage supports multiple data layouts for different test types:

```elixir
# Two-group comparison (t-test, Mann-Whitney)
context = %{
  experiment: %{reliability: %{stats: stats_config}},
  control: [0.72, 0.68, 0.75, 0.71, 0.69],
  treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
}

# Multi-group comparison (ANOVA, Kruskal-Wallis)
context = %{
  experiment: %{reliability: %{stats: stats_config}},
  groups: [
    [0.89, 0.91, 0.88, 0.90, 0.92],  # Model A
    [0.87, 0.89, 0.86, 0.88, 0.90],  # Model B
    [0.84, 0.86, 0.83, 0.85, 0.87]   # Model C
  ]
}

# Paired comparison (paired t-test, Wilcoxon)
context = %{
  experiment: %{reliability: %{stats: stats_config}},
  before: [0.72, 0.68, 0.75, 0.71, 0.69],
  after: [0.78, 0.73, 0.81, 0.76, 0.74]
}
```

### Metrics Merging

The Stage automatically merges statistical results into `context.metrics`:

```elixir
{:ok, ctx} = CrucibleBench.Stage.run(context)

ctx.metrics.bench_n           # Sample size
ctx.metrics.bench_mean        # Mean value
ctx.metrics.bench_sd          # Standard deviation
ctx.metrics.bench_ttest_p_value  # P-value from t-test (if run)
```
```

## TDD Approach

### Step 1: Write Tests First

Create new test file or extend existing:
`/home/home/p/g/North-Shore-AI/crucible_bench/test/crucible_bench/stage_test.exs`

Add these test cases:

```elixir
describe "run/2 with two groups" do
  test "performs t-test when control and treatment provided" do
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

    assert {:ok, updated} = Stage.run(context)
    assert Map.has_key?(updated.bench.tests, :ttest)
    ttest = updated.bench.tests.ttest

    assert is_number(ttest.statistic)
    assert is_number(ttest.p_value)
    assert is_boolean(ttest.significant)
    assert is_map(ttest.effect_size)
  end

  test "performs Mann-Whitney when mannwhitney requested" do
    context = %{
      experiment: %{
        reliability: %{
          stats: %CrucibleIR.Reliability.Stats{
            tests: [:mannwhitney],
            alpha: 0.05
          }
        }
      },
      control: [0.72, 0.68, 0.75, 0.71, 0.69],
      treatment: [0.78, 0.73, 0.81, 0.76, 0.74]
    }

    assert {:ok, updated} = Stage.run(context)
    assert Map.has_key?(updated.bench.tests, :mannwhitney)
  end
end

describe "run/2 with multiple groups" do
  test "performs ANOVA when groups provided" do
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
        [0.89, 0.91, 0.88, 0.90, 0.92],
        [0.87, 0.89, 0.86, 0.88, 0.90],
        [0.84, 0.86, 0.83, 0.85, 0.87]
      ]
    }

    assert {:ok, updated} = Stage.run(context)
    assert Map.has_key?(updated.bench.tests, :anova)
    anova = updated.bench.tests.anova

    assert is_number(anova.statistic)
    assert is_number(anova.p_value)
    assert is_map(anova.effect_size)
    assert Map.has_key?(anova.effect_size, :eta_squared)
  end
end

describe "run/2 with paired groups" do
  test "performs paired t-test when before and after provided" do
    context = %{
      experiment: %{
        reliability: %{
          stats: %CrucibleIR.Reliability.Stats{
            tests: [:ttest],
            alpha: 0.05
          }
        }
      },
      before: [0.72, 0.68, 0.75, 0.71, 0.69],
      after: [0.78, 0.73, 0.81, 0.76, 0.74]
    }

    assert {:ok, updated} = Stage.run(context)
    # Should detect paired data and use paired t-test
    assert Map.has_key?(updated.bench.tests, :ttest)
  end
end

describe "metrics merging" do
  test "merges statistical results into context.metrics" do
    context = %{
      experiment: %{
        reliability: %{
          stats: %CrucibleIR.Reliability.Stats{
            tests: [:bootstrap],
            alpha: 0.05
          }
        }
      },
      outputs: [0.85, 0.87, 0.84, 0.86, 0.88],
      metrics: %{existing: 123}
    }

    assert {:ok, updated} = Stage.run(context)

    # Existing metrics preserved
    assert updated.metrics.existing == 123

    # New bench metrics added
    assert is_number(updated.metrics.bench_n)
    assert is_number(updated.metrics.bench_mean)
    assert is_number(updated.metrics.bench_sd)
    assert is_number(updated.metrics.bench_median)
  end
end

describe "behaviour compliance" do
  test "run/2 accepts map context and returns ok/error tuple" do
    valid_context = %{
      experiment: %{
        reliability: %{
          stats: %CrucibleIR.Reliability.Stats{tests: [:bootstrap]}
        }
      },
      outputs: [1.0, 2.0, 3.0]
    }

    assert {:ok, _} = Stage.run(valid_context)
    assert {:ok, _} = Stage.run(valid_context, %{})
    assert {:error, _} = Stage.run(%{})
  end

  test "describe/1 returns map with required keys" do
    result = Stage.describe(%{})

    assert is_map(result)
    assert Map.has_key?(result, :name)
    assert Map.has_key?(result, :type)
    assert Map.has_key?(result, :purpose)
  end
end
```

### Step 2: Run Tests (Should Fail)

```bash
cd /home/home/p/g/North-Shore-AI/crucible_bench
mix test test/crucible_bench/stage_test.exs
```

### Step 3: Implement Changes

Edit `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`

### Step 4: Run Tests (Should Pass)

```bash
mix test test/crucible_bench/stage_test.exs
```

### Step 5: Run Full Test Suite

```bash
mix test
```

## Quality Requirements

### 1. No Compilation Warnings

```bash
mix compile --warnings-as-errors
```

### 2. Dialyzer Clean

```bash
mix dialyzer
```

Expected: No warnings or errors

### 3. Credo Strict

```bash
mix credo --strict
```

Expected: No issues

### 4. All Tests Passing

```bash
mix test
```

Expected: All tests pass

### 5. Documentation

Ensure all public functions have:
- `@doc` with description
- `@spec` with proper types
- At least one example in docs

### 6. Format Check

```bash
mix format --check-formatted
```

## File Changes Summary

1. **Edit**: `/home/home/p/g/North-Shore-AI/crucible_bench/lib/crucible_bench/stage.ex`
   - Add @behaviour declaration
   - Add @spec declarations
   - Modify extract_data/2 for multi-group support
   - Implement real test execution in execute_test/3
   - Merge results into metrics in run/2

2. **Edit**: `/home/home/p/g/North-Shore-AI/crucible_bench/test/crucible_bench/stage_test.exs`
   - Add tests for two-group comparisons
   - Add tests for multi-group comparisons
   - Add tests for paired comparisons
   - Add tests for metrics merging

3. **Edit**: `/home/home/p/g/North-Shore-AI/crucible_bench/README.md`
   - Add Advanced Stage Configuration section
   - Add Metrics Merging section
   - Update examples

## Implementation Order

1. Write new tests first (TDD)
2. Run tests to see failures
3. Add @behaviour and @spec declarations
4. Modify extract_data/2 for multi-group support
5. Implement execute_test/3 for :ttest with two groups
6. Implement execute_test/3 for :anova with multiple groups
7. Implement execute_test/3 for :mannwhitney with two groups
8. Implement execute_test/3 for paired tests
9. Add metrics merging to run/2
10. Run all tests
11. Run dialyzer
12. Run credo --strict
13. Update README.md
14. Final test run

## Verification Checklist

- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix test` all pass
- [ ] `mix dialyzer` no warnings
- [ ] `mix credo --strict` no issues
- [ ] `mix format --check-formatted` passes
- [ ] README.md updated with new examples
- [ ] All new functions have @doc and @spec
- [ ] Stage works with two-group data
- [ ] Stage works with multi-group data
- [ ] Stage works with paired data
- [ ] Stage merges results into context.metrics
