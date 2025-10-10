defmodule CrucibleBench.Stats.Power do
  @moduledoc """
  Power analysis for statistical tests.

  Calculates statistical power and required sample sizes.
  """

  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform power analysis.

  ## Options

  - `:analysis_type` - :a_priori (sample size) or :post_hoc (power)
  - `:effect_size` - Expected or observed effect size (Cohen's d)
  - `:alpha` - Significance level (default: 0.05)
  - `:power` - Desired power for a priori (default: 0.80)
  - `:n_per_group` - Sample size per group for post-hoc
  - `:alternative` - :two_sided (default), :less, :greater

  ## Examples

      # A priori: Calculate required sample size
      iex> result = CrucibleBench.Stats.Power.analyze(:t_test,
      ...>   analysis_type: :a_priori,
      ...>   effect_size: 0.5,
      ...>   alpha: 0.05,
      ...>   power: 0.80)
      iex> result.n_per_group > 0
      true

      # Post-hoc: Calculate achieved power
      iex> result = CrucibleBench.Stats.Power.analyze(:t_test,
      ...>   analysis_type: :post_hoc,
      ...>   effect_size: 0.5,
      ...>   n_per_group: 64,
      ...>   alpha: 0.05)
      iex> result.power > 0.7
      true
  """
  def analyze(test_type, opts \\ []) do
    analysis_type = Keyword.get(opts, :analysis_type, :a_priori)

    case {test_type, analysis_type} do
      {:t_test, :a_priori} -> t_test_sample_size(opts)
      {:t_test, :post_hoc} -> t_test_power(opts)
      {:anova, :a_priori} -> anova_sample_size(opts)
      {:anova, :post_hoc} -> anova_power(opts)
      _ -> raise ArgumentError, "Unknown test type or analysis type"
    end
  end

  @doc """
  Calculate required sample size for t-test.

  Based on Cohen (1988) power analysis formulas.
  """
  def t_test_sample_size(opts) do
    effect_size = Keyword.fetch!(opts, :effect_size)
    alpha = Keyword.get(opts, :alpha, 0.05)
    power = Keyword.get(opts, :power, 0.80)
    alternative = Keyword.get(opts, :alternative, :two_sided)

    # Critical values
    z_alpha = critical_value_for_alpha(alpha, alternative)
    z_beta = Distributions.normal_quantile(power)

    # Sample size calculation
    n_per_group = 2 * :math.pow((z_alpha + z_beta) / effect_size, 2)
    n_per_group = ceil(n_per_group)

    %{
      analysis_type: :a_priori,
      test: :t_test,
      n_per_group: n_per_group,
      total_n: n_per_group * 2,
      effect_size: effect_size,
      alpha: alpha,
      power: power,
      alternative: alternative,
      recommendation:
        "Collect at least #{n_per_group} samples per group (#{n_per_group * 2} total) " <>
          "to detect an effect size of #{effect_size} with #{Float.round(power * 100, 1)}% power"
    }
  end

  @doc """
  Calculate achieved power for t-test.
  """
  def t_test_power(opts) do
    effect_size = Keyword.fetch!(opts, :effect_size)
    n_per_group = Keyword.fetch!(opts, :n_per_group)
    alpha = Keyword.get(opts, :alpha, 0.05)
    alternative = Keyword.get(opts, :alternative, :two_sided)

    # Non-centrality parameter
    delta = effect_size * :math.sqrt(n_per_group / 2)

    # Critical value
    z_alpha = critical_value_for_alpha(alpha, alternative)

    # Power calculation (using normal approximation)
    power = 1 - Distributions.normal_cdf(z_alpha - delta)

    recommendation =
      cond do
        power >= 0.8 ->
          "Adequate power (#{Float.round(power * 100, 1)}%)"

        power >= 0.6 ->
          "Marginal power (#{Float.round(power * 100, 1)}%). Consider increasing sample size."

        true ->
          "Underpowered (#{Float.round(power * 100, 1)}%). Increase sample size significantly."
      end

    %{
      analysis_type: :post_hoc,
      test: :t_test,
      power: power,
      n_per_group: n_per_group,
      total_n: n_per_group * 2,
      effect_size: effect_size,
      alpha: alpha,
      alternative: alternative,
      recommendation: recommendation
    }
  end

  @doc """
  Calculate required sample size for ANOVA.
  """
  def anova_sample_size(opts) do
    effect_size = Keyword.fetch!(opts, :effect_size)
    # number of groups
    k = Keyword.fetch!(opts, :k)
    alpha = Keyword.get(opts, :alpha, 0.05)
    power = Keyword.get(opts, :power, 0.80)

    # Convert effect size to f (if given as eta-squared)
    f = if effect_size < 1, do: :math.sqrt(effect_size / (1 - effect_size)), else: effect_size

    # Critical values
    z_alpha = Distributions.normal_quantile(1 - alpha)
    z_beta = Distributions.normal_quantile(power)

    # Sample size per group (simplified formula)
    n_per_group = 1 + 2 * :math.pow((z_alpha + z_beta) / f, 2) / k
    n_per_group = ceil(n_per_group)

    %{
      analysis_type: :a_priori,
      test: :anova,
      n_per_group: n_per_group,
      total_n: n_per_group * k,
      k: k,
      effect_size: effect_size,
      alpha: alpha,
      power: power,
      recommendation:
        "Collect at least #{n_per_group} samples per group (#{n_per_group * k} total) " <>
          "to detect an effect size of #{effect_size} with #{Float.round(power * 100, 1)}% power"
    }
  end

  @doc """
  Calculate achieved power for ANOVA.
  """
  def anova_power(opts) do
    effect_size = Keyword.fetch!(opts, :effect_size)
    n_per_group = Keyword.fetch!(opts, :n_per_group)
    k = Keyword.fetch!(opts, :k)
    alpha = Keyword.get(opts, :alpha, 0.05)

    # Convert effect size to f
    f = if effect_size < 1, do: :math.sqrt(effect_size / (1 - effect_size)), else: effect_size

    # Non-centrality parameter
    lambda = n_per_group * k * f * f

    # Critical F value (approximate)
    df1 = k - 1
    df2 = k * (n_per_group - 1)

    # Power approximation (using normal approximation)
    z_alpha = Distributions.normal_quantile(1 - alpha)
    delta = :math.sqrt(lambda)
    power = 1 - Distributions.normal_cdf(z_alpha - delta)

    recommendation =
      cond do
        power >= 0.8 ->
          "Adequate power (#{Float.round(power * 100, 1)}%)"

        power >= 0.6 ->
          "Marginal power (#{Float.round(power * 100, 1)}%). Consider increasing sample size."

        true ->
          "Underpowered (#{Float.round(power * 100, 1)}%). Increase sample size significantly."
      end

    %{
      analysis_type: :post_hoc,
      test: :anova,
      power: power,
      n_per_group: n_per_group,
      total_n: n_per_group * k,
      k: k,
      effect_size: effect_size,
      alpha: alpha,
      df1: df1,
      df2: df2,
      recommendation: recommendation
    }
  end

  defp critical_value_for_alpha(alpha, :two_sided) do
    Distributions.normal_quantile(1 - alpha / 2)
  end

  defp critical_value_for_alpha(alpha, :less) do
    Distributions.normal_quantile(alpha)
  end

  defp critical_value_for_alpha(alpha, :greater) do
    Distributions.normal_quantile(1 - alpha)
  end
end
