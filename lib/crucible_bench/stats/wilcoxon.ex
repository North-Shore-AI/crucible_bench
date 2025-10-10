defmodule CrucibleBench.Stats.Wilcoxon do
  @moduledoc """
  Wilcoxon signed-rank test.

  Non-parametric alternative to paired t-test.
  Tests if the median of differences between paired samples is zero.
  """

  alias CrucibleBench.Result
  alias CrucibleBench.Stats.Distributions

  @doc """
  Perform Wilcoxon signed-rank test.

  ## Options

  - `:alternative` - :two_sided (default), :less, :greater

  ## Examples

      iex> before = [0.72, 0.68, 0.75, 0.71, 0.69]
      iex> after = [0.78, 0.73, 0.81, 0.76, 0.74]
      iex> result = CrucibleBench.Stats.Wilcoxon.test(before, after)
      iex> result.p_value < 0.05
      true
  """
  def test(group1, group2, opts \\ []) do
    unless length(group1) == length(group2) do
      raise ArgumentError, "Wilcoxon test requires equal length groups"
    end

    # Calculate differences
    differences = Enum.zip_with(group1, group2, fn x, y -> y - x end)

    # Remove zeros
    non_zero_diffs = Enum.filter(differences, fn d -> d != 0 end)
    n = length(non_zero_diffs)

    if n < 5 do
      raise ArgumentError, "Wilcoxon test requires at least 5 non-zero differences"
    end

    # Rank absolute differences
    abs_diffs = Enum.map(non_zero_diffs, &abs/1)
    ranks = assign_ranks_with_ties(abs_diffs)

    # Apply signs and sum
    signed_ranks = Enum.zip(non_zero_diffs, ranks)

    w_plus =
      signed_ranks
      |> Enum.filter(fn {diff, _} -> diff > 0 end)
      |> Enum.map(fn {_, rank} -> rank end)
      |> Enum.sum()

    w_minus =
      signed_ranks
      |> Enum.filter(fn {diff, _} -> diff < 0 end)
      |> Enum.map(fn {_, rank} -> rank end)
      |> Enum.sum()

    w_stat = min(w_plus, w_minus)

    # For large samples (n > 25), use normal approximation
    p_value =
      if n > 25 do
        mu = n * (n + 1) / 4
        sigma = :math.sqrt(n * (n + 1) * (2 * n + 1) / 24)
        z = (w_stat - mu) / sigma

        alternative = Keyword.get(opts, :alternative, :two_sided)

        case alternative do
          :two_sided -> 2 * (1 - Distributions.normal_cdf(abs(z)))
          :less -> Distributions.normal_cdf(z)
          :greater -> 1 - Distributions.normal_cdf(z)
        end
      else
        # For small samples, approximate p-value
        # Would normally use exact distribution table
        mu = n * (n + 1) / 4
        sigma = :math.sqrt(n * (n + 1) * (2 * n + 1) / 24)
        z = (w_stat - mu) / sigma
        2 * (1 - Distributions.normal_cdf(abs(z)))
      end

    # Effect size (r = Z / sqrt(n))
    effect_size =
      if n > 25 do
        mu = n * (n + 1) / 4
        sigma = :math.sqrt(n * (n + 1) * (2 * n + 1) / 24)
        z = (w_stat - mu) / sigma
        abs(z) / :math.sqrt(n)
      else
        nil
      end

    %Result{
      test: :wilcoxon_signed_rank,
      statistic: w_stat,
      p_value: p_value,
      effect_size: if(effect_size, do: %{r: effect_size}, else: nil),
      interpretation: interpret(p_value),
      metadata: %{
        w_plus: w_plus,
        w_minus: w_minus,
        n: n,
        n_zero: length(differences) - n
      }
    }
  end

  defp assign_ranks_with_ties(values) do
    indexed = Enum.with_index(values)
    sorted = Enum.sort_by(indexed, fn {val, _idx} -> val end)

    # Group by value to handle ties
    grouped = Enum.chunk_by(sorted, fn {val, _idx} -> val end)

    ranks =
      Enum.reduce(grouped, {[], 1}, fn group, {acc, start_rank} ->
        group_size = length(group)
        avg_rank = (start_rank + start_rank + group_size - 1) / 2
        ranks_for_group = Enum.map(group, fn {_val, idx} -> {idx, avg_rank} end)
        {acc ++ ranks_for_group, start_rank + group_size}
      end)
      |> elem(0)
      |> Enum.sort_by(fn {idx, _rank} -> idx end)
      |> Enum.map(fn {_idx, rank} -> rank end)

    ranks
  end

  defp interpret(p_value) do
    cond do
      p_value < 0.001 -> "Highly significant difference between paired groups"
      p_value < 0.01 -> "Very significant difference between paired groups"
      p_value < 0.05 -> "Significant difference between paired groups"
      true -> "No significant difference between paired groups"
    end
  end
end
