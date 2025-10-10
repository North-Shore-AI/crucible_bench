defmodule CrucibleBench do
  @moduledoc """
  Bench - Statistical Testing Framework for AI Research

  A comprehensive statistical testing framework designed specifically for AI/ML research.
  Provides rigorous statistical tests, effect size measures, power analysis, and
  publication-ready reporting.

  ## Core Capabilities

  - **Parametric Tests**: t-tests, ANOVA
  - **Non-Parametric Tests**: Mann-Whitney U, Wilcoxon signed-rank, Kruskal-Wallis
  - **Effect Sizes**: Cohen's d, Hedges' g, eta-squared, omega-squared
  - **Power Analysis**: A priori and post-hoc power calculations
  - **Confidence Intervals**: Bootstrap and analytical methods
  - **Multiple Comparison Correction**: Bonferroni, Holm, Benjamini-Hochberg

  ## Quick Start

      # Compare two groups
      control = [0.72, 0.68, 0.75, 0.71, 0.69]
      treatment = [0.78, 0.73, 0.81, 0.76, 0.74]

      CrucibleBench.compare(control, treatment)

  ## Design Principles

  1. **Statistical Rigor**: All implementations validated against R/SciPy
  2. **Interpretability**: Every result includes effect sizes
  3. **Reproducibility**: Complete audit trails
  4. **Peer-Review Ready**: Publication-quality output
  """

  alias CrucibleBench.Stats
  alias CrucibleBench.Analysis
  alias CrucibleBench.Experiment

  @doc """
  Compare two independent groups with automatic test selection.

  Automatically selects appropriate test based on data characteristics and
  assumption checking. Returns comprehensive results including p-value,
  effect size, confidence interval, and interpretation.

  ## Options

  - `:test` - Force specific test (:t_test, :welch_t_test, :mann_whitney)
  - `:confidence_level` - Confidence level for CI (default: 0.95)
  - `:check_assumptions` - Test normality and variance (default: true)
  - `:alternative` - :two_sided (default), :less, :greater

  ## Examples

      iex> control = [5.1, 4.9, 5.3, 5.0, 5.2]
      iex> treatment = [6.2, 6.0, 6.4, 5.9, 6.1]
      iex> result = CrucibleBench.compare(control, treatment)
      iex> result.p_value < 0.05
      true

  ## Returns

  A `CrucibleBench.Result` struct containing:
  - `test`: Test type used
  - `statistic`: Test statistic value
  - `p_value`: P-value
  - `effect_size`: Effect size measure
  - `confidence_interval`: CI for mean difference
  - `interpretation`: Human-readable interpretation
  """
  def compare(group1, group2, opts \\ []) do
    Analysis.compare_groups(group1, group2, opts)
  end

  @doc """
  Perform paired comparison between related groups.

  Use when samples are paired (e.g., before/after measurements on same subjects).

  ## Examples

      iex> before = [0.72, 0.68, 0.75, 0.71, 0.69]
      iex> after_values = [0.78, 0.73, 0.81, 0.76, 0.74]
      iex> result = CrucibleBench.compare_paired(before, after_values)
      iex> result.effect_size.mean_diff > 0
      true
  """
  def compare_paired(group1, group2, opts \\ []) do
    Analysis.compare_paired(group1, group2, opts)
  end

  @doc """
  Compare multiple groups (3+) with ANOVA or Kruskal-Wallis.

  Automatically selects parametric (ANOVA) or non-parametric (Kruskal-Wallis)
  test based on assumption checking.

  ## Examples

      iex> gpt4 = [0.89, 0.91, 0.88, 0.90, 0.92]
      iex> claude = [0.87, 0.89, 0.86, 0.88, 0.90]
      iex> gemini = [0.84, 0.86, 0.83, 0.85, 0.87]
      iex> result = CrucibleBench.compare_multiple([gpt4, claude, gemini])
      iex> result.test in [:anova, :kruskal_wallis]
      true
  """
  def compare_multiple(groups, opts \\ []) do
    Analysis.compare_multiple(groups, opts)
  end

  @doc """
  Calculate effect size between two groups.

  Returns Cohen's d or appropriate effect size measure.

  ## Examples

      iex> group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      iex> group2 = [6.0, 6.2, 5.8, 6.1, 5.9]
      iex> effect = CrucibleBench.effect_size(group1, group2)
      iex> effect.cohens_d < 0
      true
  """
  def effect_size(group1, group2, opts \\ []) do
    Stats.EffectSize.calculate(group1, group2, opts)
  end

  @doc """
  Calculate confidence interval for a statistic.

  Supports both analytical and bootstrap methods.

  ## Options

  - `:method` - :analytical (default) or :bootstrap
  - `:confidence_level` - Confidence level (default: 0.95)
  - `:iterations` - Bootstrap iterations (default: 10000)

  ## Examples

      iex> data = [5.0, 5.2, 4.8, 5.1, 4.9, 5.3]
      iex> ci = CrucibleBench.confidence_interval(data, :mean)
      iex> {lower, upper} = ci.interval
      iex> lower < 5.05 and upper > 5.05
      true
  """
  def confidence_interval(data, statistic, opts \\ []) do
    Stats.ConfidenceInterval.calculate(data, statistic, opts)
  end

  @doc """
  Perform power analysis for a test.

  Calculate required sample size or achieved power.

  ## Options

  - `:analysis_type` - :a_priori (sample size) or :post_hoc (power)
  - `:effect_size` - Expected or observed effect size
  - `:alpha` - Significance level (default: 0.05)
  - `:power` - Desired power (default: 0.80)

  ## Examples

      iex> # Calculate required sample size
      iex> result = CrucibleBench.power_analysis(:t_test,
      ...>   effect_size: 0.5, alpha: 0.05, power: 0.80)
      iex> result.n_per_group > 0
      true
  """
  def power_analysis(test_type, opts \\ []) do
    Stats.Power.analyze(test_type, opts)
  end

  @doc """
  Run an experiment with automatic analysis.

  High-level DSL for common experiment patterns.

  ## Experiment Types

  - `:ab_test` - A/B testing
  - `:ablation` - Ablation study
  - `:hyperparameter_sweep` - Hyperparameter optimization

  ## Examples

      iex> control = [0.72, 0.68, 0.75, 0.71, 0.69]
      iex> treatment = [0.78, 0.73, 0.81, 0.76, 0.74]
      iex> result = CrucibleBench.experiment(:ab_test,
      ...>   control: control, treatment: treatment,
      ...>   name: "Prompt Engineering Test")
      iex> result.significant?
      true
  """
  def experiment(type, opts \\ []) do
    Experiment.run(type, opts)
  end
end
