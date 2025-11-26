# CrucibleBench Enhancement Design (2025-11-25)

## Goals
- Strengthen statistical rigor around assumptions (normality, equal variances).
- Control family-wise and false-discovery error rates for multiple testing.
- Improve experiment reporting so corrected p-values and methods are explicit.

## Scope
- New normality utilities: Shapiro-Wilk, combined assessment, quick skew/kurtosis screening.
- Variance equality utilities: Levene (Brown-Forsythe), two-sample F-test, quick variance ratio check.
- Multiple comparison corrections: Bonferroni, Holm step-down (FWER), Benjamini-Hochberg (FDR).
- Hyperparameter sweep integration: pairwise comparisons automatically corrected, reported method noted.
- Export updates: pairwise tables show original/adjusted p-values and significance under correction.

## Key Design Decisions
- **Defensive math**: All stats functions now guard zero-variance and boundary cases to avoid crashing and to return interpretable defaults.
- **Corrections surfaced**: `MultipleComparisons.correct/2` returns both original and adjusted p-values plus flags; sweep experiments propagate the chosen correction method for transparency.
- **FDR awareness**: Benjamini-Hochberg paths honor `:fdr_level` for significance decisions; default remains 0.05.
- **Interpretability**: Effects and recommendations are preserved in experiment outputs so reports stay actionable after corrections.

## Usage Notes
- Normality: use `NormalityTests.assess_normality/1` for a full view (Shapiro-Wilk + skew/kurtosis). Fall back to `quick_check/1` for lightweight gating.
- Variances: prefer `VarianceTests.levene_test/2` for robustness; `f_test/2` assumes normality; `quick_check/2` is a fast heuristic.
- Multiple comparisons: call `MultipleComparisons.correct/2` or rely on sweep experiments’ automatic correction. Choose `:holm` (default) for balanced control or `:benjamini_hochberg` for exploratory work; set `fdr_level:` as needed.
- Exports: pairwise tables include original and adjusted p-values plus significance under the chosen correction method; the correction name is printed in reports.

## Testing
- Added dedicated test suites for normality, variance, and multiple comparison modules.
- Coverage includes boundary cases (constant data, tiny samples), monotonicity of adjusted p-values, and integration of corrections into experiment outputs.
