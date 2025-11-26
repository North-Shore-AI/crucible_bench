defmodule CrucibleBench.Stats do
  @moduledoc """
  Core statistical functions and utilities.

  Provides basic statistical calculations used throughout the framework.
  """

  @doc """
  Calculate mean (average) of a list of numbers.

  ## Examples

      iex> CrucibleBench.Stats.mean([1, 2, 3, 4, 5])
      3.0
  """
  def mean([]), do: nil

  def mean(values) when is_list(values) do
    Enum.sum(values) / length(values)
  end

  @doc """
  Calculate median of a list of numbers.

  ## Examples

      iex> CrucibleBench.Stats.median([1, 2, 3, 4, 5])
      3.0

      iex> CrucibleBench.Stats.median([1, 2, 3, 4])
      2.5
  """
  def median([]), do: nil

  def median(values) when is_list(values) do
    sorted = Enum.sort(values)
    n = length(sorted)
    mid = div(n, 2)

    if rem(n, 2) == 1 do
      Enum.at(sorted, mid)
    else
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    end
  end

  @doc """
  Calculate variance of a list of numbers.

  ## Options

  - `:sample` - If true (default), uses n-1 denominator (sample variance)
  - `:population` - If true, uses n denominator (population variance)

  ## Examples

      iex> CrucibleBench.Stats.variance([1, 2, 3, 4, 5])
      2.5
  """
  def variance(values, opts \\ [])
  def variance([], _opts), do: nil
  def variance([_single], _opts), do: 0.0

  def variance(values, opts) when is_list(values) do
    m = mean(values)
    n = length(values)

    sum_sq_diff =
      Enum.reduce(values, 0, fn x, acc ->
        acc + :math.pow(x - m, 2)
      end)

    denominator = if Keyword.get(opts, :population, false), do: n, else: n - 1
    sum_sq_diff / denominator
  end

  @doc """
  Calculate standard deviation of a list of numbers.

  ## Examples

      iex> CrucibleBench.Stats.stdev([1, 2, 3, 4, 5])
      1.5811388300841898
  """
  def stdev(values, opts \\ []) do
    case variance(values, opts) do
      nil -> nil
      var -> :math.sqrt(var)
    end
  end

  @doc """
  Calculate standard error of the mean.

  ## Examples

      iex> CrucibleBench.Stats.sem([1, 2, 3, 4, 5])
      0.7071067811865476
  """
  def sem([]), do: nil

  def sem(values) when is_list(values) do
    sd = stdev(values)
    n = length(values)
    sd / :math.sqrt(n)
  end

  @doc """
  Calculate quantile at given probability.

  ## Examples

      iex> CrucibleBench.Stats.quantile([1, 2, 3, 4, 5], 0.5)
      3.0
  """
  def quantile([], _p), do: nil

  def quantile(values, p) when is_list(values) and p >= 0 and p <= 1 do
    sorted = Enum.sort(values)
    n = length(sorted)
    index = p * (n - 1)
    lower_idx = floor(index)
    upper_idx = ceil(index)

    if lower_idx == upper_idx do
      Enum.at(sorted, round(index))
    else
      lower_val = Enum.at(sorted, lower_idx)
      upper_val = Enum.at(sorted, upper_idx)
      fraction = index - lower_idx
      lower_val + fraction * (upper_val - lower_val)
    end
  end

  @doc """
  Calculate z-score for each value in a list.

  ## Examples

      iex> CrucibleBench.Stats.z_scores([1, 2, 3, 4, 5])
      [-1.2649110640673518, -0.6324555320336759, 0.0, 0.6324555320336759, 1.2649110640673518]
  """
  def z_scores([]), do: []

  def z_scores(values) when is_list(values) do
    m = mean(values)
    sd = stdev(values)

    if is_nil(sd) or sd == 0.0 do
      # All values identical or insufficient variance
      Enum.map(values, fn _ -> 0.0 end)
    else
      Enum.map(values, fn x -> (x - m) / sd end)
    end
  end

  @doc """
  Calculate skewness of a distribution.

  Positive skew means right tail is longer.
  Negative skew means left tail is longer.
  """
  def skewness([]), do: nil
  def skewness(values) when is_list(values) and length(values) < 3, do: nil

  def skewness(values) when is_list(values) do
    n = length(values)
    m = mean(values)
    sd = stdev(values)

    if is_nil(sd) or sd == 0.0 do
      # Zero variance implies perfectly symmetric distribution
      0.0
    else
      sum_cubed =
        Enum.reduce(values, 0, fn x, acc ->
          acc + :math.pow((x - m) / sd, 3)
        end)

      n / ((n - 1) * (n - 2)) * sum_cubed
    end
  end

  @doc """
  Calculate kurtosis of a distribution.

  Excess kurtosis > 0 means heavy tails (leptokurtic).
  Excess kurtosis < 0 means light tails (platykurtic).
  """
  def kurtosis([]), do: nil
  def kurtosis(values) when is_list(values) and length(values) < 4, do: nil

  def kurtosis(values) when is_list(values) do
    n = length(values)
    m = mean(values)
    sd = stdev(values)

    if is_nil(sd) or sd == 0.0 do
      # Degenerate distribution; treat excess kurtosis as 0
      0.0
    else
      sum_fourth =
        Enum.reduce(values, 0, fn x, acc ->
          acc + :math.pow((x - m) / sd, 4)
        end)

      numerator = n * (n + 1) * sum_fourth
      denominator = (n - 1) * (n - 2) * (n - 3)
      correction = 3 * :math.pow(n - 1, 2) / ((n - 2) * (n - 3))

      numerator / denominator - correction
    end
  end

  @doc """
  Calculate correlation coefficient between two variables.

  Returns Pearson correlation coefficient (-1 to 1).

  ## Examples

      iex> x = [1, 2, 3, 4, 5]
      iex> y = [2, 4, 6, 8, 10]
      iex> CrucibleBench.Stats.correlation(x, y)
      1.0
  """
  def correlation(x, y) when length(x) != length(y) do
    raise ArgumentError, "Lists must have equal length"
  end

  def correlation([], []), do: nil

  def correlation(x, y) when is_list(x) and is_list(y) do
    mean_x = mean(x)
    mean_y = mean(y)

    numerator =
      Enum.zip(x, y)
      |> Enum.reduce(0, fn {xi, yi}, acc ->
        acc + (xi - mean_x) * (yi - mean_y)
      end)

    sum_sq_x =
      Enum.reduce(x, 0, fn xi, acc ->
        acc + :math.pow(xi - mean_x, 2)
      end)

    sum_sq_y =
      Enum.reduce(y, 0, fn yi, acc ->
        acc + :math.pow(yi - mean_y, 2)
      end)

    denominator = :math.sqrt(sum_sq_x * sum_sq_y)

    if denominator == 0.0 do
      0.0
    else
      numerator / denominator
    end
  end

  @doc """
  Rank values in ascending order, handling ties by averaging.

  ## Examples

      iex> CrucibleBench.Stats.rank([5, 2, 8, 2, 9])
      [3.0, 1.5, 4.0, 1.5, 5.0]
  """
  def rank([]), do: []

  def rank(values) when is_list(values) do
    indexed = Enum.with_index(values)
    sorted = Enum.sort_by(indexed, fn {val, _idx} -> val end)

    # Group by value to handle ties
    grouped = Enum.chunk_by(sorted, fn {val, _idx} -> val end)

    ranks =
      Enum.reduce(grouped, {[], 1}, fn group, {acc, start_rank} ->
        group_size = length(group)
        # Average rank for ties
        avg_rank = (start_rank + start_rank + group_size - 1) / 2
        ranks_for_group = Enum.map(group, fn {_val, idx} -> {idx, avg_rank} end)
        {acc ++ ranks_for_group, start_rank + group_size}
      end)
      |> elem(0)
      |> Enum.sort_by(fn {idx, _rank} -> idx end)
      |> Enum.map(fn {_idx, rank} -> rank end)

    ranks
  end
end
