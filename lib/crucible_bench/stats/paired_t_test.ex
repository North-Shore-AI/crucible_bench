defmodule CrucibleBench.Stats.PairedTTest do
  @moduledoc """
  Paired samples t-test.

  Compares means of two related groups (e.g., before/after measurements).
  """

  alias CrucibleBench.{Stats, Result}
  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform paired samples t-test.

  ## Options

  - `:mu` - Hypothesized mean difference (default: 0.0)
  - `:alternative` - :two_sided (default), :less, :greater
  - `:confidence_level` - Confidence level for CI (default: 0.95)

  ## Examples

      iex> before = [0.72, 0.68, 0.75, 0.71, 0.69]
      iex> after = [0.78, 0.73, 0.81, 0.76, 0.74]
      iex> result = CrucibleBench.Stats.PairedTTest.test(before, after)
      iex> result.p_value < 0.05
      true
  """
  def test(group1, group2, opts \\ []) do
    unless length(group1) == length(group2) do
      raise ArgumentError, "Paired test requires equal length groups"
    end

    # Calculate differences
    differences = Enum.zip_with(group1, group2, fn x, y -> y - x end)

    n = length(differences)
    mean_diff = Stats.mean(differences)
    sd_diff = Stats.stdev(differences)
    se_diff = sd_diff / :math.sqrt(n)

    mu0 = Keyword.get(opts, :mu, 0.0)
    t_stat = (mean_diff - mu0) / se_diff
    df = n - 1

    alternative = Keyword.get(opts, :alternative, :two_sided)
    p_value = p_value_from_t(t_stat, df, alternative)

    # Confidence interval
    conf_level = Keyword.get(opts, :confidence_level, 0.95)
    alpha = 1 - conf_level
    t_critical = Distributions.t_quantile(df, 1 - alpha / 2)
    margin = t_critical * se_diff
    ci = {mean_diff - margin, mean_diff + margin}

    %Result{
      test: :paired_t_test,
      statistic: t_stat,
      p_value: p_value,
      confidence_interval: ci,
      interpretation: interpret(p_value, mean_diff),
      metadata: %{
        df: df,
        mean_diff: mean_diff,
        sd_diff: sd_diff,
        se_diff: se_diff,
        alternative: alternative,
        n: n
      }
    }
  end

  defp p_value_from_t(t_stat, df, alternative) do
    p_two_sided = 2 * (1 - Distributions.t_cdf(abs(t_stat), df))

    case alternative do
      :two_sided -> p_two_sided
      :greater -> 1 - Distributions.t_cdf(t_stat, df)
      :less -> Distributions.t_cdf(t_stat, df)
    end
  end

  defp interpret(p_value, mean_diff) do
    sig_text =
      cond do
        p_value < 0.001 -> "Highly significant"
        p_value < 0.01 -> "Very significant"
        p_value < 0.05 -> "Significant"
        true -> "No significant"
      end

    direction = if mean_diff > 0, do: "increase", else: "decrease"
    "#{sig_text} #{direction} from first to second group"
  end
end
