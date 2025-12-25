# CrucibleBench: Inspect-AI Parity Requirements (2025-12-24)

Purpose: document how (and whether) CrucibleBench is needed for inspect-ai
parity in the tinker-cookbook eval path.

## Python Sources (line referenced)

Inspect-AI eval logs and analysis:
- `tinkex_cookbook/inspect_ai/src/inspect_ai/log/_log.py:921-957`
  `EvalLog` structure (results, metrics, samples, stats).
- `tinkex_cookbook/inspect_ai/src/inspect_ai/analysis/_dataframe/evals/extract.py:20-42`
  metrics extraction from `EvalLog`.

Cookbook references:
- `tinkex_cookbook/tinker-cookbook/docs/evals.mdx:32-49`
  offline evals via inspect-ai (results are analyzed externally).
- `tinkex_cookbook/tinker-cookbook/docs/preferences/dpo-guide.mdx:93-104`
  suggests running inspect evals after DPO training.

## Current CrucibleBench Coverage (Elixir)

- `../crucible_bench/lib/crucible_bench/stage.ex:1-200`
  pipeline stage for statistical tests on numeric outputs.
- `../crucible_bench/lib/crucible_bench/stats/*`
  statistical tests (t-test, ANOVA, Wilcoxon, etc).

## Required Functionality for Full Parity

inspect-ai itself does not provide statistical benchmarking; it provides logs
and metrics. If we want a native analysis/benchmarking story in Elixir:

1. Parse evaluation results into a stable metric schema (EvalLog equivalent).
2. Feed metric distributions into CrucibleBench for statistical tests.

## Status (v0.3.1)

- Added EvalLog-compatible schema for inspect-ai-style logs.
- Added adapter from EvalEx.Result to CrucibleBench.EvalLog.
- Added extraction helpers mirroring inspect-ai analysis functions.

## Remaining Gaps

- No built-in persistence format for EvalLog (in-memory only).

## Implication for Cookbook Parity

CrucibleBench is optional for reproducing the cookbook's eval runtime behavior.
It becomes relevant only if you want inspect-ai style analysis on stored eval
results (e.g., to compare runs or compute statistical significance).
