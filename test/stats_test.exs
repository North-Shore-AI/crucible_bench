defmodule CrucibleBench.StatsTest do
  use ExUnit.Case
  alias CrucibleBench.Stats

  describe "mean/1" do
    test "calculates mean of list" do
      assert Stats.mean([1, 2, 3, 4, 5]) == 3.0
      assert Stats.mean([10, 20, 30]) == 20.0
    end

    test "returns nil for empty list" do
      assert Stats.mean([]) == nil
    end
  end

  describe "median/1" do
    test "calculates median for odd-length list" do
      assert Stats.median([1, 2, 3, 4, 5]) == 3.0
    end

    test "calculates median for even-length list" do
      assert Stats.median([1, 2, 3, 4]) == 2.5
    end

    test "returns nil for empty list" do
      assert Stats.median([]) == nil
    end
  end

  describe "variance/1" do
    test "calculates sample variance" do
      data = [1, 2, 3, 4, 5]
      var = Stats.variance(data)
      assert_in_delta var, 2.5, 0.01
    end

    test "returns 0 for single value" do
      assert Stats.variance([5]) == 0.0
    end
  end

  describe "stdev/1" do
    test "calculates standard deviation" do
      data = [1, 2, 3, 4, 5]
      sd = Stats.stdev(data)
      assert_in_delta sd, 1.58, 0.01
    end
  end

  describe "sem/1" do
    test "calculates standard error of mean" do
      data = [1, 2, 3, 4, 5]
      sem = Stats.sem(data)
      assert_in_delta sem, 0.707, 0.01
    end
  end

  describe "quantile/2" do
    test "calculates quantiles" do
      data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

      # Median (50th percentile)
      assert Stats.quantile(data, 0.5) == 5.5

      # First quartile
      q1 = Stats.quantile(data, 0.25)
      assert q1 >= 2 and q1 <= 4

      # Third quartile
      q3 = Stats.quantile(data, 0.75)
      assert q3 >= 7 and q3 <= 9
    end
  end

  describe "correlation/2" do
    test "calculates perfect positive correlation" do
      x = [1, 2, 3, 4, 5]
      y = [2, 4, 6, 8, 10]
      assert_in_delta Stats.correlation(x, y), 1.0, 0.01
    end

    test "calculates perfect negative correlation" do
      x = [1, 2, 3, 4, 5]
      y = [10, 8, 6, 4, 2]
      assert_in_delta Stats.correlation(x, y), -1.0, 0.01
    end

    test "raises error for unequal lengths" do
      assert_raise ArgumentError, fn ->
        Stats.correlation([1, 2, 3], [1, 2])
      end
    end
  end

  describe "rank/1" do
    test "assigns ranks correctly" do
      data = [5, 2, 8, 2, 9]
      ranks = Stats.rank(data)
      assert ranks == [3.0, 1.5, 4.0, 1.5, 5.0]
    end

    test "handles all equal values" do
      data = [5, 5, 5]
      ranks = Stats.rank(data)
      assert Enum.all?(ranks, &(&1 == 2.0))
    end
  end

  describe "skewness/1" do
    test "detects positive skew" do
      # Right-skewed data
      data = [1, 1, 1, 2, 2, 3, 10]
      skew = Stats.skewness(data)
      assert skew > 0
    end

    test "detects negative skew" do
      # Left-skewed data
      data = [1, 8, 9, 9, 10, 10, 10]
      skew = Stats.skewness(data)
      assert skew < 0
    end
  end

  describe "kurtosis/1" do
    test "calculates kurtosis" do
      data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      kurt = Stats.kurtosis(data)
      assert is_number(kurt)
    end

    test "returns nil for insufficient data" do
      assert Stats.kurtosis([1, 2]) == nil
    end
  end
end
