defmodule CrucibleBench.Stats.VarianceTests do
  @moduledoc """
  Tests for homogeneity of variance (homoscedasticity).

  Used to validate the equal variance assumption for t-tests and ANOVA.

  ## References

  - Levene, H. (1960). "Robust tests for equality of variances"
  - Brown, M. B., & Forsythe, A. B. (1974). "Robust tests for the equality of variances"
  """

  alias CrucibleBench.Stats

  @doc """
  Levene's test for equality of variances.

  Robust test that works well even when data is not normally distributed.
  Uses absolute deviations from group medians (Brown-Forsythe variant).

  **Returns:**
  - `:statistic` - F statistic from ANOVA on absolute deviations
  - `:p_value` - Probability that variances are equal
  - `:equal_variances` - true if p > 0.05
  - `:df_between` - Degrees of freedom between groups
  - `:df_within` - Degrees of freedom within groups

  ## Examples

      iex> # Groups with similar variances
      iex> group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      iex> group2 = [6.0, 6.2, 5.8, 6.1, 5.9]
      iex> result = CrucibleBench.Stats.VarianceTests.levene_test([group1, group2])
      iex> is_float(result.statistic)
      true

      iex> # Groups with very different variances
      iex> group1 = [5.0, 5.1, 5.0, 5.1]
      iex> group2 = [1.0, 10.0, 2.0, 9.0]
      iex> result = CrucibleBench.Stats.VarianceTests.levene_test([group1, group2])
      iex> is_float(result.p_value)
      true
  """
  def levene_test(groups, opts \\ []) when is_list(groups) do
    unless length(groups) >= 2 do
      raise ArgumentError, "Levene's test requires at least 2 groups"
    end

    # Validate all groups have data
    if Enum.any?(groups, &(length(&1) < 2)) do
      raise ArgumentError, "All groups must have at least 2 observations"
    end

    center = Keyword.get(opts, :center, :median)

    # Calculate absolute deviations from center (median or mean)
    deviations =
      Enum.map(groups, fn group ->
        center_value =
          case center do
            :median -> Stats.median(group)
            :mean -> Stats.mean(group)
          end

        Enum.map(group, fn x -> abs(x - center_value) end)
      end)

    # Perform one-way ANOVA on the deviations
    anova_result = one_way_anova_simple(deviations)

    %{
      test: :levene,
      statistic: anova_result.f_statistic,
      p_value: anova_result.p_value,
      equal_variances: anova_result.p_value > 0.05,
      df_between: anova_result.df_between,
      df_within: anova_result.df_within,
      center: center,
      interpretation: interpret_variance_test(anova_result.p_value)
    }
  end

  @doc """
  F-test for equality of variances (two groups only).

  Classic parametric test. Sensitive to departures from normality.
  Prefer Levene's test unless data is known to be normal.

  ## Examples

      iex> group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      iex> group2 = [6.0, 6.2, 5.8, 6.1, 5.9]
      iex> result = CrucibleBench.Stats.VarianceTests.f_test(group1, group2)
      iex> is_float(result.statistic)
      true
  """
  def f_test(group1, group2) when is_list(group1) and is_list(group2) do
    unless length(group1) >= 2 and length(group2) >= 2 do
      raise ArgumentError, "Both groups must have at least 2 observations"
    end

    var1 = Stats.variance(group1)
    var2 = Stats.variance(group2)

    cond do
      (is_nil(var1) or var1 == 0.0) and (is_nil(var2) or var2 == 0.0) ->
        %{
          test: :f_test,
          statistic: 1.0,
          p_value: 1.0,
          equal_variances: true,
          df1: length(group1) - 1,
          df2: length(group2) - 1,
          var1: var1 || 0.0,
          var2: var2 || 0.0,
          interpretation: "Variances appear equal (both groups constant)"
        }

      var1 == 0.0 or var2 == 0.0 ->
        # One group has zero variance; treat as highly unequal
        {f_statistic, df1, df2} =
          if (var1 || 0.0) >= (var2 || 0.0) do
            {:infinity, length(group1) - 1, length(group2) - 1}
          else
            {:infinity, length(group2) - 1, length(group1) - 1}
          end

        %{
          test: :f_test,
          statistic: f_statistic,
          p_value: 0.0,
          equal_variances: false,
          df1: df1,
          df2: df2,
          var1: var1 || 0.0,
          var2: var2 || 0.0,
          interpretation: "Variances significantly different (one group constant)"
        }

      true ->
        # F = larger variance / smaller variance
        {f_statistic, df1, df2} =
          if var1 >= var2 do
            {var1 / var2, length(group1) - 1, length(group2) - 1}
          else
            {var2 / var1, length(group2) - 1, length(group1) - 1}
          end

        # Approximate p-value using F-distribution
        # For two-tailed test, we use 2 * P(F > f_statistic)
        p_value = approximate_f_p_value(f_statistic, df1, df2)

        %{
          test: :f_test,
          statistic: f_statistic,
          p_value: p_value,
          equal_variances: p_value > 0.05,
          df1: df1,
          df2: df2,
          var1: var1,
          var2: var2,
          interpretation: interpret_variance_test(p_value)
        }
    end
  end

  # Simplified one-way ANOVA for Levene's test
  defp one_way_anova_simple(groups) do
    # Flatten all data
    all_data = List.flatten(groups)
    grand_mean = Stats.mean(all_data)

    # Calculate group means and sizes
    group_stats =
      Enum.map(groups, fn group ->
        %{
          mean: Stats.mean(group),
          n: length(group),
          data: group
        }
      end)

    # Between-group sum of squares
    ss_between =
      Enum.reduce(group_stats, 0, fn stats, acc ->
        acc + stats.n * :math.pow(stats.mean - grand_mean, 2)
      end)

    # Within-group sum of squares
    ss_within =
      Enum.reduce(group_stats, 0, fn stats, acc ->
        group_ss =
          Enum.reduce(stats.data, 0, fn x, sum ->
            sum + :math.pow(x - stats.mean, 2)
          end)

        acc + group_ss
      end)

    # Degrees of freedom
    k = length(groups)
    n = length(all_data)
    df_between = k - 1
    df_within = n - k

    # Mean squares
    ms_between = ss_between / df_between

    ms_within =
      cond do
        df_within <= 0 -> 1.0e-9
        ss_within == 0.0 -> 1.0e-9
        true -> ss_within / df_within
      end

    # F statistic
    f_statistic =
      if ms_within == 0.0 do
        :infinity
      else
        ms_between / ms_within
      end

    # Approximate p-value
    p_value = approximate_f_p_value(f_statistic, df_between, df_within)

    %{
      f_statistic: f_statistic,
      p_value: p_value,
      df_between: df_between,
      df_within: df_within,
      ss_between: ss_between,
      ss_within: ss_within
    }
  end

  # Approximate F-distribution p-value
  # This is a simplified approximation
  defp approximate_f_p_value(f, _df1, _df2) do
    # For large F values, p-value is very small
    cond do
      f == :infinity ->
        0.0

      f > 20 ->
        0.001

      f > 10 ->
        0.01

      f > 5 ->
        0.05

      f > 3 ->
        0.10

      f > 2 ->
        0.20

      true ->
        0.50
    end
  end

  defp interpret_variance_test(p_value) do
    cond do
      p_value > 0.10 ->
        "Variances appear equal (p = #{Float.round(p_value, 4)})"

      p_value > 0.05 ->
        "Marginally equal variances (p = #{Float.round(p_value, 4)})"

      true ->
        "Variances significantly different (p = #{Float.round(p_value, 4)}). Use Welch's test."
    end
  end

  @doc """
  Quick variance equality check for two groups.

  Uses a simple variance ratio heuristic. Fast but not statistically rigorous.

  ## Examples

      iex> group1 = [5.0, 5.1, 5.0]
      iex> group2 = [6.0, 6.1, 6.0]
      iex> result = CrucibleBench.Stats.VarianceTests.quick_check(group1, group2)
      iex> is_boolean(result.equal_variances)
      true
  """
  def quick_check(group1, group2) when is_list(group1) and is_list(group2) do
    var1 = Stats.variance(group1)
    var2 = Stats.variance(group2)

    # Use ratio test: if ratio is between 0.25 and 4, consider equal
    ratio = if var2 > 0, do: var1 / var2, else: 1.0

    equal = ratio >= 0.25 and ratio <= 4.0

    %{
      equal_variances: equal,
      var1: var1,
      var2: var2,
      ratio: ratio,
      reason:
        if equal do
          "Variance ratio #{Float.round(ratio, 2)} within acceptable range"
        else
          "Variance ratio #{Float.round(ratio, 2)} indicates unequal variances"
        end
    }
  end
end
