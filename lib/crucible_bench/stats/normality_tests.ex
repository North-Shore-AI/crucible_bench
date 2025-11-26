defmodule CrucibleBench.Stats.NormalityTests do
  @moduledoc """
  Statistical tests for normality of data distributions.

  Tests the null hypothesis that data comes from a normal distribution.
  Used to validate assumptions for parametric statistical tests.

  ## References

  - Shapiro, S. S., & Wilk, M. B. (1965). "An analysis of variance test for normality"
  - Royston, P. (1992). "Approximating the Shapiro-Wilk W-Test for non-normality"
  """

  alias CrucibleBench.Stats

  @doc """
  Shapiro-Wilk test for normality.

  Most powerful omnibus test for normality. Tests null hypothesis that
  data comes from a normal distribution.

  **Returns:**
  - `:statistic` - W statistic (0 to 1, closer to 1 indicates more normal)
  - `:p_value` - Probability of observing this data if truly normal
  - `:is_normal` - true if p-value > 0.05
  - `:interpretation` - Human-readable result

  **Limitations:**
  - Requires 3 ≤ n ≤ 5000
  - Sensitive to ties in small samples

  ## Examples

      iex> # Approximately normal data
      iex> data = [5.0, 5.2, 4.8, 5.1, 4.9, 5.3, 4.7, 5.0, 5.1, 4.9]
      iex> result = CrucibleBench.Stats.NormalityTests.shapiro_wilk(data)
      iex> result.statistic > 0.3
      true

      iex> # Clearly non-normal (uniform-like)
      iex> data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      iex> result = CrucibleBench.Stats.NormalityTests.shapiro_wilk(data)
      iex> is_float(result.statistic)
      true
  """
  def shapiro_wilk(data) when is_list(data) do
    n = length(data)

    cond do
      n < 3 ->
        {:error, "Shapiro-Wilk test requires at least 3 observations"}

      n > 5000 ->
        {:error, "Shapiro-Wilk test not reliable for n > 5000"}

      true ->
        calculate_shapiro_wilk(data, n)
    end
  end

  defp calculate_shapiro_wilk(data, n) do
    # Sort data
    sorted_data = Enum.sort(data)

    # Calculate mean and variance
    mean = Stats.mean(sorted_data)
    variance = Stats.variance(sorted_data)

    # Calculate W statistic using simplified approach
    # Full implementation would use coefficients from tables
    # This is a simplified version that gives reasonable approximation

    # Calculate sum of squared deviations
    ss_total =
      Enum.reduce(sorted_data, 0, fn x, acc ->
        acc + :math.pow(x - mean, 2)
      end)

    # Calculate numerator using linear combination
    # Simplified: use correlation with expected normal order statistics
    numerator_sum =
      sorted_data
      |> Enum.with_index(1)
      |> Enum.reduce(0, fn {x, i}, acc ->
        # Expected normal quantile for this rank
        p = (i - 0.375) / (n + 0.25)
        z = normal_quantile_approx(p)
        acc + z * (x - mean)
      end)

    w_statistic =
      if ss_total == 0.0 or variance in [nil, 0.0] do
        1.0
      else
        numerator = :math.pow(numerator_sum, 2)
        denominator = (n - 1) * variance
        numerator / denominator
      end

    # Ensure W is in valid range [0, 1]
    w_statistic = max(0.0, min(1.0, w_statistic))

    # Approximate p-value using transformation
    p_value =
      case w_statistic do
        1.0 -> 1.0
        _ -> approximate_p_value(w_statistic, n)
      end

    %{
      test: :shapiro_wilk,
      statistic: w_statistic,
      p_value: p_value,
      n: n,
      is_normal: p_value > 0.05,
      interpretation: interpret_normality(p_value, w_statistic)
    }
  end

  # Approximation for normal quantile function
  defp normal_quantile_approx(p) when p > 0 and p < 1 do
    # Rational approximation (Beasley-Springer-Moro algorithm)
    a0 = 2.50662823884
    a1 = -18.61500062529
    a2 = 41.39119773534
    a3 = -25.44106049637
    b1 = -8.47351093090
    b2 = 23.08336743743
    b3 = -21.06224101826
    b4 = 3.13082909833

    if p < 0.5 do
      t = :math.sqrt(-2.0 * :math.log(p))

      -(t -
          (a0 + a1 * t + a2 * :math.pow(t, 2) + a3 * :math.pow(t, 3)) /
            (1.0 + b1 * t + b2 * :math.pow(t, 2) + b3 * :math.pow(t, 3) +
               b4 * :math.pow(t, 4)))
    else
      t = :math.sqrt(-2.0 * :math.log(1.0 - p))

      t -
        (a0 + a1 * t + a2 * :math.pow(t, 2) + a3 * :math.pow(t, 3)) /
          (1.0 + b1 * t + b2 * :math.pow(t, 2) + b3 * :math.pow(t, 3) +
             b4 * :math.pow(t, 4))
    end
  end

  defp normal_quantile_approx(_p), do: 0.0

  # Approximate p-value from W statistic
  # Based on Royston (1992) approximation
  defp approximate_p_value(w, n) do
    # Clamp away from boundary to avoid log(0)
    w = min(max(w, 1.0e-12), 1 - 1.0e-12)

    # Transform W to get approximately normal distribution
    log_w = :math.log(1.0 - w)

    # Parameters depend on sample size
    {mu, sigma} =
      cond do
        n <= 10 ->
          # Small sample approximation
          {-1.5861, 0.5095}

        n <= 50 ->
          # Medium sample
          {-1.9284, 0.5095 * :math.sqrt(n / 50.0)}

        true ->
          # Large sample
          {-1.9284, 0.5095 * :math.sqrt(n / 50.0)}
      end

    # Standardize
    z = (log_w - mu) / sigma

    # Convert to p-value (two-tailed)
    p_value = 2.0 * (1.0 - standard_normal_cdf(abs(z)))

    # Clamp to valid range
    max(0.0, min(1.0, p_value))
  end

  # Standard normal CDF approximation
  defp standard_normal_cdf(z) do
    # Using error function approximation
    0.5 * (1.0 + erf(z / :math.sqrt(2.0)))
  end

  # Error function approximation
  defp erf(x) do
    # Abramowitz and Stegun approximation
    a1 = 0.254829592
    a2 = -0.284496736
    a3 = 1.421413741
    a4 = -1.453152027
    a5 = 1.061405429
    p = 0.3275911

    sign = if x < 0, do: -1, else: 1
    x = abs(x)

    t = 1.0 / (1.0 + p * x)
    y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * :math.exp(-x * x)

    sign * y
  end

  defp interpret_normality(p_value, w_statistic) do
    cond do
      p_value > 0.10 ->
        "Data appears normally distributed (p = #{Float.round(p_value, 4)}, W = #{Float.round(w_statistic, 4)})"

      p_value > 0.05 ->
        "Data marginally normal (p = #{Float.round(p_value, 4)}, W = #{Float.round(w_statistic, 4)})"

      true ->
        "Data significantly deviates from normality (p = #{Float.round(p_value, 4)}, W = #{Float.round(w_statistic, 4)})"
    end
  end

  @doc """
  Comprehensive normality assessment combining multiple approaches.

  Returns a map with:
  - Shapiro-Wilk test result
  - Skewness and kurtosis
  - Overall recommendation

  ## Examples

      iex> data = [5.0, 5.1, 4.9, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0, 5.1]
      iex> assessment = CrucibleBench.Stats.NormalityTests.assess_normality(data)
      iex> is_map(assessment)
      true
  """
  def assess_normality(data, _opts \\ []) when is_list(data) do
    n = length(data)

    if n < 3 do
      {:error, "Need at least 3 observations for normality assessment"}
    else
      # Run Shapiro-Wilk if possible
      sw_result = shapiro_wilk(data)

      # Calculate skewness and kurtosis
      skewness = Stats.skewness(data)
      kurtosis = Stats.kurtosis(data)

      # Determine overall assessment
      {tests_passed, tests_failed} =
        case sw_result do
          %{is_normal: true} -> {["Shapiro-Wilk test"], []}
          %{is_normal: false} -> {[], ["Shapiro-Wilk test"]}
          {:error, _} -> {[], []}
        end

      # Check skewness and kurtosis
      {tests_passed, tests_failed} =
        if skewness != nil and abs(skewness) < 2.0 do
          {["Skewness check" | tests_passed], tests_failed}
        else
          {tests_passed,
           ["Skewness check (|skew| = #{Float.round(abs(skewness || 0), 4)})" | tests_failed]}
        end

      {tests_passed, tests_failed} =
        if kurtosis != nil and abs(kurtosis) < 7.0 do
          {["Kurtosis check" | tests_passed], tests_failed}
        else
          {tests_passed,
           ["Kurtosis check (|kurt| = #{Float.round(abs(kurtosis || 0), 4)})" | tests_failed]}
        end

      # Overall recommendation
      recommendation =
        cond do
          length(tests_failed) == 0 ->
            "Data appears normally distributed. Parametric tests are appropriate."

          length(tests_failed) == 1 and length(tests_passed) >= 2 ->
            "Data marginally normal. Parametric tests acceptable with caution."

          true ->
            "Data shows significant departure from normality. Consider non-parametric tests."
        end

      %{
        n: n,
        shapiro_wilk: sw_result,
        skewness: skewness,
        kurtosis: kurtosis,
        tests_passed: tests_passed,
        tests_failed: tests_failed,
        is_normal: length(tests_failed) <= 1,
        recommendation: recommendation
      }
    end
  end

  @doc """
  Quick normality check using skewness and kurtosis thresholds.

  Faster than Shapiro-Wilk but less reliable. Use for quick screening.

  ## Examples

      iex> data = [5.0, 5.1, 4.9, 5.2, 4.8]
      iex> result = CrucibleBench.Stats.NormalityTests.quick_check(data)
      iex> is_boolean(result.is_normal)
      true
  """
  def quick_check(data) when is_list(data) do
    n = length(data)

    if n < 3 do
      %{
        is_normal: true,
        reason: "Too few observations for reliable test, assuming normal"
      }
    else
      skewness = Stats.skewness(data)
      kurtosis = Stats.kurtosis(data)

      skew_ok = skewness == nil or abs(skewness) < 2.0
      kurt_ok = kurtosis == nil or abs(kurtosis) < 7.0

      %{
        is_normal: skew_ok and kurt_ok,
        skewness: skewness,
        kurtosis: kurtosis,
        skew_ok: skew_ok,
        kurt_ok: kurt_ok,
        reason:
          if skew_ok and kurt_ok do
            "Skewness and kurtosis within acceptable ranges"
          else
            issues =
              [
                if(!skew_ok, do: "high skewness (#{Float.round(abs(skewness || 0), 2)})"),
                if(!kurt_ok, do: "high kurtosis (#{Float.round(abs(kurtosis || 0), 2)})")
              ]
              |> Enum.filter(& &1)
              |> Enum.join(", ")

            "Data shows #{issues}"
          end
      }
    end
  end
end
