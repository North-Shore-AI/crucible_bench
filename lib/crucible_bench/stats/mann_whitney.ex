defmodule CrucibleBench.Stats.MannWhitney do
  @moduledoc """
  Mann-Whitney U test (Wilcoxon rank-sum test).

  Non-parametric alternative to independent samples t-test.
  Tests if two independent samples come from the same distribution.
  """

  alias CrucibleBench.Result
  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform Mann-Whitney U test.

  ## Options

  - `:alternative` - :two_sided (default), :less, :greater

  ## Examples

      iex> control = [120, 135, 118, 142, 125, 890]  # Has outlier
      iex> treatment = [98, 105, 102, 110, 95, 108]
      iex> result = CrucibleBench.Stats.MannWhitney.test(control, treatment)
      iex> result.test == :mann_whitney
      true
  """
  def test(group1, group2, opts \\ []) do
    n1 = length(group1)
    n2 = length(group2)

    # Combine and rank all values
    combined = Enum.map(group1, &{:group1, &1}) ++ Enum.map(group2, &{:group2, &1})
    sorted = Enum.sort_by(combined, fn {_, val} -> val end)

    # Assign ranks (handle ties by averaging)
    ranks = assign_ranks(sorted)

    # Sum ranks for each group
    r1 =
      ranks
      |> Enum.filter(fn {group, _, _} -> group == :group1 end)
      |> Enum.map(fn {_, _, rank} -> rank end)
      |> Enum.sum()

    r2 =
      ranks
      |> Enum.filter(fn {group, _, _} -> group == :group2 end)
      |> Enum.map(fn {_, _, rank} -> rank end)
      |> Enum.sum()

    # Calculate U statistics
    u1 = n1 * n2 + n1 * (n1 + 1) / 2 - r1
    u2 = n1 * n2 + n2 * (n2 + 1) / 2 - r2

    # Use smaller U
    u_stat = min(u1, u2)

    # For large samples, use normal approximation
    {p_value, z_stat} =
      if n1 > 20 and n2 > 20 do
        mu_u = n1 * n2 / 2
        sigma_u = :math.sqrt(n1 * n2 * (n1 + n2 + 1) / 12)

        # Continuity correction
        z = (u_stat - mu_u + 0.5) / sigma_u

        alternative = Keyword.get(opts, :alternative, :two_sided)

        p =
          case alternative do
            :two_sided -> 2 * (1 - Distributions.normal_cdf(abs(z)))
            :less -> Distributions.normal_cdf(z)
            :greater -> 1 - Distributions.normal_cdf(z)
          end

        {p, z}
      else
        # For small samples, would use exact distribution
        # For simplicity, using normal approximation with warning
        mu_u = n1 * n2 / 2
        sigma_u = :math.sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
        z = (u_stat - mu_u + 0.5) / sigma_u
        p = 2 * (1 - Distributions.normal_cdf(abs(z)))
        {p, z}
      end

    # Effect size (rank-biserial correlation)
    r_rb = 1 - 2 * u_stat / (n1 * n2)

    %Result{
      test: :mann_whitney,
      statistic: u_stat,
      p_value: p_value,
      effect_size: %{
        rank_biserial: r_rb,
        interpretation: interpret_rank_biserial(r_rb)
      },
      interpretation: interpret(p_value, r_rb),
      metadata: %{
        u1: u1,
        u2: u2,
        z_statistic: z_stat,
        n1: n1,
        n2: n2,
        r1: r1,
        r2: r2
      }
    }
  end

  defp assign_ranks(sorted_values) do
    sorted_values
    |> Enum.chunk_by(fn {_, val} -> val end)
    |> Enum.reduce({[], 1}, fn chunk, {acc, start_rank} ->
      chunk_size = length(chunk)
      avg_rank = (start_rank + start_rank + chunk_size - 1) / 2

      ranked_chunk = Enum.map(chunk, fn {group, val} -> {group, val, avg_rank} end)
      {acc ++ ranked_chunk, start_rank + chunk_size}
    end)
    |> elem(0)
  end

  defp interpret_rank_biserial(r) do
    cond do
      abs(r) < 0.1 -> "negligible"
      abs(r) < 0.3 -> "small"
      abs(r) < 0.5 -> "medium"
      true -> "large"
    end
  end

  defp interpret(p_value, r_rb) do
    sig_text =
      cond do
        p_value < 0.001 -> "Highly significant"
        p_value < 0.01 -> "Very significant"
        p_value < 0.05 -> "Significant"
        true -> "No significant"
      end

    effect_text = interpret_rank_biserial(r_rb)
    "#{sig_text} difference between groups (#{effect_text} effect)"
  end
end
