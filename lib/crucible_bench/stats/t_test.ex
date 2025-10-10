defmodule CrucibleBench.Stats.TTest do
  @moduledoc """
  Independent samples t-test with Welch correction.

  Compares means of two independent groups to determine if they
  differ significantly.
  """

  alias CrucibleBench.{Stats, Result}
  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform independent samples t-test.

  Automatically uses Welch's t-test (does not assume equal variances)
  unless explicitly specified otherwise.

  ## Options

  - `:var_equal` - Assume equal variances (default: false)
  - `:alternative` - :two_sided (default), :less, :greater
  - `:confidence_level` - Confidence level for CI (default: 0.95)

  ## Examples

      iex> group1 = [5.1, 4.9, 5.3, 5.0, 5.2]
      iex> group2 = [6.2, 6.0, 6.4, 5.9, 6.1]
      iex> result = CrucibleBench.Stats.TTest.test(group1, group2)
      iex> result.p_value < 0.05
      true
  """
  def test(group1, group2, opts \\ []) do
    n1 = length(group1)
    n2 = length(group2)

    mean1 = Stats.mean(group1)
    mean2 = Stats.mean(group2)
    var1 = Stats.variance(group1)
    var2 = Stats.variance(group2)

    var_equal = Keyword.get(opts, :var_equal, false)

    {t_stat, df} =
      if var_equal do
        student_t(mean1, mean2, var1, var2, n1, n2)
      else
        welch_t(mean1, mean2, var1, var2, n1, n2)
      end

    alternative = Keyword.get(opts, :alternative, :two_sided)
    p_value = p_value_from_t(t_stat, df, alternative)

    # Confidence interval
    conf_level = Keyword.get(opts, :confidence_level, 0.95)
    ci = confidence_interval(mean1, mean2, var1, var2, n1, n2, df, conf_level, var_equal)

    %Result{
      test: if(var_equal, do: :student_t_test, else: :welch_t_test),
      statistic: t_stat,
      p_value: p_value,
      confidence_interval: ci,
      interpretation: interpret(p_value, t_stat),
      metadata: %{
        df: df,
        mean1: mean1,
        mean2: mean2,
        mean_diff: mean1 - mean2,
        alternative: alternative,
        n1: n1,
        n2: n2
      }
    }
  end

  defp student_t(mean1, mean2, var1, var2, n1, n2) do
    # Pooled variance
    pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2)

    # Standard error
    se = :math.sqrt(pooled_var * (1 / n1 + 1 / n2))

    # t-statistic
    t = (mean1 - mean2) / se
    df = n1 + n2 - 2

    {t, df}
  end

  defp welch_t(mean1, mean2, var1, var2, n1, n2) do
    # Standard error (no pooling)
    se = :math.sqrt(var1 / n1 + var2 / n2)

    # t-statistic
    t = (mean1 - mean2) / se

    # Welch-Satterthwaite degrees of freedom
    numerator = :math.pow(var1 / n1 + var2 / n2, 2)
    denominator = :math.pow(var1 / n1, 2) / (n1 - 1) + :math.pow(var2 / n2, 2) / (n2 - 1)
    df = numerator / denominator

    {t, df}
  end

  defp confidence_interval(mean1, mean2, var1, var2, n1, n2, df, conf_level, var_equal) do
    mean_diff = mean1 - mean2

    se =
      if var_equal do
        pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2)
        :math.sqrt(pooled_var * (1 / n1 + 1 / n2))
      else
        :math.sqrt(var1 / n1 + var2 / n2)
      end

    alpha = 1 - conf_level
    t_critical = Distributions.t_quantile(df, 1 - alpha / 2)
    margin = t_critical * se

    {mean_diff - margin, mean_diff + margin}
  end

  defp p_value_from_t(t_stat, df, alternative) do
    p_two_sided = 2 * (1 - Distributions.t_cdf(abs(t_stat), df))

    case alternative do
      :two_sided -> p_two_sided
      :greater -> 1 - Distributions.t_cdf(t_stat, df)
      :less -> Distributions.t_cdf(t_stat, df)
    end
  end

  defp interpret(p_value, _t_stat) do
    cond do
      p_value < 0.001 -> "Highly significant difference between groups"
      p_value < 0.01 -> "Very significant difference between groups"
      p_value < 0.05 -> "Significant difference between groups"
      true -> "No significant difference between groups"
    end
  end
end
