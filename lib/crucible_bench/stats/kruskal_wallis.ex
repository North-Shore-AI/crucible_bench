defmodule CrucibleBench.Stats.KruskalWallis do
  @moduledoc """
  Kruskal-Wallis H test.

  Non-parametric alternative to one-way ANOVA.
  Tests if multiple independent samples come from the same distribution.
  """

  alias CrucibleBench.Result
  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform Kruskal-Wallis test.

  ## Options

  - `:alpha` - Significance level (default: 0.05)

  ## Examples

      iex> group1 = [5, 7, 8, 6, 9]
      iex> group2 = [3, 4, 5, 4, 6]
      iex> group3 = [1, 2, 3, 2, 4]
      iex> result = CrucibleBench.Stats.KruskalWallis.test([group1, group2, group3])
      iex> result.test == :kruskal_wallis
      true
  """
  def test(groups, _opts \\ []) when is_list(groups) do
    unless length(groups) >= 2 do
      raise ArgumentError, "Kruskal-Wallis test requires at least 2 groups"
    end

    # Combine all groups with labels
    combined =
      groups
      |> Enum.with_index()
      |> Enum.flat_map(fn {group, idx} ->
        Enum.map(group, fn val -> {idx, val} end)
      end)

    # Sort and rank
    sorted = Enum.sort_by(combined, fn {_, val} -> val end)
    ranks = assign_ranks(sorted)

    # Calculate rank sums for each group
    k = length(groups)
    n_total = length(sorted)

    rank_sums =
      ranks
      |> Enum.group_by(fn {group_idx, _, _} -> group_idx end)
      |> Enum.map(fn {idx, group_ranks} ->
        {idx, Enum.sum(Enum.map(group_ranks, fn {_, _, rank} -> rank end))}
      end)
      |> Map.new()

    # H statistic
    h_stat =
      12 / (n_total * (n_total + 1)) *
        Enum.sum(
          Enum.map(groups, fn group ->
            idx = Enum.find_index(groups, &(&1 == group))
            n = length(group)
            r = Map.get(rank_sums, idx)
            :math.pow(r, 2) / n
          end)
        ) - 3 * (n_total + 1)

    # p-value from chi-squared distribution
    df = k - 1
    p_value = 1 - Distributions.chi_squared_cdf(h_stat, df)

    # Effect size (epsilon-squared)
    epsilon_sq = h_stat / (n_total - 1)

    %Result{
      test: :kruskal_wallis,
      statistic: h_stat,
      p_value: p_value,
      effect_size: %{
        epsilon_squared: epsilon_sq,
        interpretation: interpret_epsilon_squared(epsilon_sq)
      },
      interpretation: interpret(p_value, epsilon_sq),
      metadata: %{
        df: df,
        k: k,
        n_total: n_total,
        rank_sums: rank_sums
      }
    }
  end

  defp assign_ranks(sorted_values) do
    sorted_values
    |> Enum.chunk_by(fn {_, val} -> val end)
    |> Enum.reduce({[], 1}, fn chunk, {acc, start_rank} ->
      chunk_size = length(chunk)
      avg_rank = (start_rank + start_rank + chunk_size - 1) / 2

      ranked_chunk = Enum.map(chunk, fn {group_idx, val} -> {group_idx, val, avg_rank} end)
      {acc ++ ranked_chunk, start_rank + chunk_size}
    end)
    |> elem(0)
  end

  defp interpret_epsilon_squared(eps) do
    cond do
      eps >= 0.14 -> "large"
      eps >= 0.06 -> "medium"
      eps >= 0.01 -> "small"
      true -> "negligible"
    end
  end

  defp interpret(p_value, eps) do
    sig_text =
      cond do
        p_value < 0.001 -> "Highly significant"
        p_value < 0.01 -> "Very significant"
        p_value < 0.05 -> "Significant"
        true -> "No significant"
      end

    effect_text = interpret_epsilon_squared(eps)
    "#{sig_text} difference between groups (#{effect_text} effect)"
  end
end
