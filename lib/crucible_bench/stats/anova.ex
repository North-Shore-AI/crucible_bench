defmodule CrucibleBench.Stats.ANOVA do
  @moduledoc """
  One-way Analysis of Variance (ANOVA).

  Compares means across 3+ independent groups to determine if at least
  one group differs significantly from the others.
  """

  alias CrucibleBench.{Stats, Result}
  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform one-way ANOVA.

  ## Options

  - `:alpha` - Significance level (default: 0.05)
  - `:labels` - Group labels for reporting

  ## Examples

      iex> gpt4 = [0.89, 0.91, 0.88, 0.90, 0.92]
      iex> claude = [0.87, 0.89, 0.86, 0.88, 0.90]
      iex> gemini = [0.84, 0.86, 0.83, 0.85, 0.87]
      iex> result = CrucibleBench.Stats.ANOVA.one_way([gpt4, claude, gemini])
      iex> result.p_value < 0.05
      true
  """
  def one_way(groups, _opts \\ []) when is_list(groups) do
    unless length(groups) >= 2 do
      raise ArgumentError, "ANOVA requires at least 2 groups"
    end

    k = length(groups)
    n_total = Enum.sum(Enum.map(groups, &length/1))

    # Grand mean
    all_values = List.flatten(groups)
    grand_mean = Stats.mean(all_values)

    # Between-group sum of squares
    ss_between =
      groups
      |> Enum.map(fn group ->
        n = length(group)
        group_mean = Stats.mean(group)
        n * :math.pow(group_mean - grand_mean, 2)
      end)
      |> Enum.sum()

    # Within-group sum of squares
    ss_within =
      groups
      |> Enum.map(fn group ->
        group_mean = Stats.mean(group)

        Enum.map(group, fn x -> :math.pow(x - group_mean, 2) end)
        |> Enum.sum()
      end)
      |> Enum.sum()

    # Total sum of squares
    ss_total = Enum.map(all_values, fn x -> :math.pow(x - grand_mean, 2) end) |> Enum.sum()

    # Degrees of freedom
    df_between = k - 1
    df_within = n_total - k

    # Mean squares
    ms_between = ss_between / df_between
    ms_within = ss_within / df_within

    # F-statistic
    f_stat = ms_between / ms_within

    # p-value from F-distribution
    p_value = 1 - Distributions.f_cdf(f_stat, df_between, df_within)

    # Effect sizes
    eta_squared = ss_between / ss_total
    omega_squared = (ss_between - df_between * ms_within) / (ss_total + ms_within)

    effect_interpretation =
      cond do
        eta_squared >= 0.14 -> "large"
        eta_squared >= 0.06 -> "medium"
        eta_squared >= 0.01 -> "small"
        true -> "negligible"
      end

    %Result{
      test: :anova,
      statistic: f_stat,
      p_value: p_value,
      effect_size: %{
        eta_squared: eta_squared,
        omega_squared: omega_squared,
        interpretation: effect_interpretation
      },
      interpretation: interpret(p_value, eta_squared),
      metadata: %{
        df_between: df_between,
        df_within: df_within,
        ss_between: ss_between,
        ss_within: ss_within,
        ss_total: ss_total,
        ms_between: ms_between,
        ms_within: ms_within,
        k: k,
        n_total: n_total,
        group_means: Enum.map(groups, &Stats.mean/1)
      }
    }
  end

  defp interpret(p_value, eta_squared) do
    sig_text =
      cond do
        p_value < 0.001 -> "Highly significant"
        p_value < 0.01 -> "Very significant"
        p_value < 0.05 -> "Significant"
        true -> "No significant"
      end

    effect_text =
      cond do
        eta_squared >= 0.14 -> "large"
        eta_squared >= 0.06 -> "medium"
        eta_squared >= 0.01 -> "small"
        true -> "negligible"
      end

    "#{sig_text} difference between groups (#{effect_text} effect)"
  end
end
