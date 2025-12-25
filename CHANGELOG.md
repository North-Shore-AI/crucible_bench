# Changelog

All notable changes to this project will be documented in this file.

## [0.3.1] - 2025-12-24

### Added
- **EvalLog Schema:** Inspect-ai compatible evaluation log structs
- **EvalEx Adapter:** Convert EvalEx.Result into CrucibleBench.EvalLog
- **Metric Extraction:** Helpers mirroring inspect-ai analysis extractors

### Documentation
- README updated with EvalLog adapter usage
- Inspect-ai parity requirements updated with current status

## [0.3.0] - 2025-11-26

### Added
- **CrucibleIR Integration** - Added dependency on `crucible_ir ~> 0.1.1` for shared IR structures
- **CrucibleBench.Stage** - New pipeline stage module for integration with crucible_framework
  - Implements stage behaviour for use in pipeline orchestration
  - Accepts `CrucibleIR.Reliability.Stats` configuration from experiment context
  - Extracts and analyzes data from pipeline context (`:outputs` or `:metrics` keys)
  - Returns comprehensive statistical analysis in `:bench` context key
  - Supports test selection, confidence intervals, and bootstrap analysis
  - Provides `describe/1` function for stage introspection
- **IR Config Support** - Main `CrucibleBench.compare/3` function now accepts `CrucibleIR.Reliability.Stats` struct
  - Automatically converts IR configuration to internal options format
  - Maintains backwards compatibility with keyword list options
  - Maps IR test types (`:ttest`, `:bootstrap`, etc.) to CrucibleBench implementations

### Changed
- Version bumped to 0.3.0 (MINOR version due to new functionality)
- Enhanced `CrucibleBench` module with multi-clause function definitions for config handling

### Documentation
- Complete API documentation for `CrucibleBench.Stage` module
- Updated README with Stage usage examples
- Enhanced main module documentation with IR config examples

### Testing
- New comprehensive test suite for `CrucibleBench.Stage` (18 tests)
- Tests cover context processing, error handling, config conversion, and integration
- Property-based validation of IR config acceptance

## [0.2.1] - 2025-11-25

### Added
- **Multiple Comparison Corrections** - Controls Type I error rates when conducting multiple tests
  - Bonferroni correction (most conservative, controls FWER)
  - Holm step-down method (less conservative than Bonferroni, still controls FWER)
  - Benjamini-Hochberg FDR correction (controls false discovery rate, more powerful)
  - New module: `CrucibleBench.Stats.MultipleComparisons`
  - Integration with hyperparameter sweep experiments (automatic p-value adjustment)
  - Detailed correction results with original and adjusted p-values

- **Formal Normality Tests** - Statistical tests for distribution assumptions
  - Shapiro-Wilk test (most powerful omnibus test, n = 3 to 5000)
  - Comprehensive normality assessment combining multiple approaches
  - Quick normality check using skewness/kurtosis thresholds
  - New module: `CrucibleBench.Stats.NormalityTests`

- **Variance Equality Tests** - Validates homogeneity of variance assumptions
  - Levene's test (robust to non-normality, uses median-based deviations)
  - F-test for two groups (parametric, sensitive to normality)
  - Quick variance check using variance ratios
  - New module: `CrucibleBench.Stats.VarianceTests`

### Changed
- Hyperparameter sweep experiments now apply multiple comparison corrections by default (Holm method)
- Export module updated to display adjusted p-values in pairwise comparison tables
- Experiment results include correction method information

### Documentation
- Comprehensive enhancement design document in `docs/20251125/enhancement_design.md`
- Complete API documentation for all new modules
- Examples demonstrating each new feature
- Best practices for multiple comparison handling

### Testing
- 3 new comprehensive test suites (multiple_comparisons_test, normality_tests_test, variance_tests_test)
- Property-based testing for monotonicity and boundary conditions
- Integration tests demonstrating end-to-end functionality

## [0.2.0] - 2025-11-24

### Added
- Complete statistical testing framework with parametric (Student's, Welch's, paired t-tests, one-way ANOVA) and non-parametric (Mann-Whitney U, Wilcoxon signed-rank, Kruskal-Wallis) coverage using accurate distribution functions
- Expanded effect size suite including Cohen's d, Hedges' g, Glass's delta, paired Cohen's d, eta-squared/omega-squared, and rank-biserial correlation with interpretation guidance
- Confidence intervals (analytical and bootstrap) and power analysis (a priori and post-hoc for t-tests and ANOVA) with actionable recommendations
- High-level analysis helpers for automatic test selection plus experiment DSL for A/B tests, ablation studies, and hyperparameter sweeps
- Publication-ready exports to Markdown, LaTeX, and HTML with standardized result metadata

## [0.1.0] - 2025-10-07

### Added
- Initial release
- Comprehensive statistical testing framework for AI/ML research
- Parametric tests (t-tests, ANOVA) and non-parametric tests (Mann-Whitney, Wilcoxon, Kruskal-Wallis)
- Effect size measures (Cohen's d, Hedges' g, Glass's delta, eta-squared, omega-squared)
- Power analysis with a priori and post-hoc calculations
- Confidence intervals using bootstrap and analytical methods
- High-level experiment DSL for A/B tests, ablation studies, and hyperparameter sweeps
- Publication-ready export formats (Markdown, LaTeX, HTML)

### Documentation
- Comprehensive README with examples
- API documentation for all statistical tests
- Usage examples for common AI research scenarios
- Best practices guide for statistical rigor in AI research
