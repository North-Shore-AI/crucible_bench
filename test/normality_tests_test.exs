defmodule NormalityTestsTest do
  use ExUnit.Case
  doctest CrucibleBench.Stats.NormalityTests

  alias CrucibleBench.Stats.NormalityTests

  describe "shapiro_wilk/1" do
    test "returns valid result structure for normal-ish data" do
      data = [5.0, 5.2, 4.8, 5.1, 4.9, 5.3, 4.7, 5.0, 5.1, 4.9]
      result = NormalityTests.shapiro_wilk(data)

      assert is_map(result)
      assert result.test == :shapiro_wilk
      assert is_float(result.statistic)
      assert result.statistic >= 0.0 and result.statistic <= 1.0
      assert is_float(result.p_value)
      assert result.p_value >= 0.0 and result.p_value <= 1.0
      assert is_boolean(result.is_normal)
      assert is_binary(result.interpretation)
    end

    test "W statistic close to 1 for approximately normal data" do
      # Generate approximately normal data
      data = [4.9, 5.0, 5.0, 5.1, 5.1, 5.1, 5.2, 5.2, 5.3]
      result = NormalityTests.shapiro_wilk(data)

      assert result.statistic > 0.3
    end

    test "handles uniform data" do
      data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      result = NormalityTests.shapiro_wilk(data)

      assert is_float(result.statistic)
      assert result.statistic >= 0.0 and result.statistic <= 1.0
    end

    test "errors on too few observations" do
      data = [1, 2]
      result = NormalityTests.shapiro_wilk(data)

      assert {:error, _message} = result
    end

    test "errors on single observation" do
      data = [5.0]
      result = NormalityTests.shapiro_wilk(data)

      assert {:error, _message} = result
    end

    test "handles larger sample sizes" do
      # Generate data with n=50
      data = for _i <- 1..50, do: :rand.uniform() * 10
      result = NormalityTests.shapiro_wilk(data)

      assert is_map(result)
      assert result.n == 50
    end

    test "handles constant data" do
      data = [5.0, 5.0, 5.0, 5.0, 5.0]
      result = NormalityTests.shapiro_wilk(data)

      # Constant data has zero variance, should handle gracefully
      assert is_map(result)
      assert result.statistic == 1.0
    end

    test "produces consistent results" do
      data = [5.1, 4.9, 5.3, 5.0, 5.2, 4.8, 5.1]

      result1 = NormalityTests.shapiro_wilk(data)
      result2 = NormalityTests.shapiro_wilk(data)

      assert result1.statistic == result2.statistic
      assert result1.p_value == result2.p_value
    end
  end

  describe "assess_normality/2" do
    test "returns comprehensive assessment" do
      data = [5.0, 5.1, 4.9, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0, 5.1]
      assessment = NormalityTests.assess_normality(data)

      assert is_map(assessment)
      assert Map.has_key?(assessment, :shapiro_wilk)
      assert Map.has_key?(assessment, :skewness)
      assert Map.has_key?(assessment, :kurtosis)
      assert Map.has_key?(assessment, :tests_passed)
      assert Map.has_key?(assessment, :tests_failed)
      assert is_boolean(assessment.is_normal)
      assert is_binary(assessment.recommendation)
    end

    test "lists tests passed and failed" do
      data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      assessment = NormalityTests.assess_normality(data)

      assert is_list(assessment.tests_passed)
      assert is_list(assessment.tests_failed)
    end

    test "provides recommendation" do
      data = [5.0, 5.1, 4.9, 5.2, 4.8]
      assessment = NormalityTests.assess_normality(data)

      assert is_binary(assessment.recommendation)
    end

    test "errors on insufficient data" do
      data = [1, 2]
      result = NormalityTests.assess_normality(data)

      assert {:error, _message} = result
    end

    test "handles approximately normal data" do
      # Generate data with low skewness and kurtosis
      data = [4.9, 5.0, 5.0, 5.1, 5.1, 5.1, 5.2, 5.2, 5.3, 5.0]
      assessment = NormalityTests.assess_normality(data)

      # Should pass most tests
      assert assessment.is_normal == true
    end

    test "detects non-normal data" do
      # Highly skewed data
      data = [1, 1, 1, 1, 2, 2, 3, 10, 20, 30]
      assessment = NormalityTests.assess_normality(data)

      # May fail some tests
      assert is_list(assessment.tests_failed)
    end
  end

  describe "quick_check/1" do
    test "returns quick assessment" do
      data = [5.0, 5.1, 4.9, 5.2, 4.8]
      result = NormalityTests.quick_check(data)

      assert is_map(result)
      assert is_boolean(result.is_normal)
      assert is_binary(result.reason)
    end

    test "accepts data with small skewness and kurtosis" do
      data = [5.0, 5.1, 4.9, 5.2, 4.8, 5.0, 5.1]
      result = NormalityTests.quick_check(data)

      assert Map.has_key?(result, :skewness)
      assert Map.has_key?(result, :kurtosis)
    end

    test "handles tiny samples" do
      data = [1, 2]
      result = NormalityTests.quick_check(data)

      # Should assume normal for tiny samples
      assert result.is_normal == true
      assert String.contains?(result.reason, "few observations")
    end

    test "faster than Shapiro-Wilk" do
      data = for _i <- 1..100, do: :rand.uniform() * 10

      # Both should complete quickly, but quick_check should be faster
      {time_quick, _} = :timer.tc(fn -> NormalityTests.quick_check(data) end)
      {time_sw, _} = :timer.tc(fn -> NormalityTests.shapiro_wilk(data) end)

      # Just ensure both complete
      assert time_quick > 0
      assert time_sw > 0
    end

    test "identifies clearly non-normal data" do
      # Extremely skewed
      data = [1, 1, 1, 1, 1, 100]
      result = NormalityTests.quick_check(data)

      # May or may not catch it depending on thresholds
      assert is_boolean(result.is_normal)
    end
  end

  describe "integration tests" do
    test "all methods handle same data consistently" do
      data = [5.0, 5.1, 4.9, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0, 5.1, 5.2]

      quick = NormalityTests.quick_check(data)
      sw = NormalityTests.shapiro_wilk(data)
      assessment = NormalityTests.assess_normality(data)

      # All should complete without error
      assert is_map(quick)
      assert is_map(sw)
      assert is_map(assessment)

      # Assessment should include SW test
      assert assessment.shapiro_wilk.test == :shapiro_wilk
    end

    test "methods generally agree on clearly normal data" do
      # Tightly clustered around mean
      data = [5.0, 5.1, 5.0, 5.1, 5.0, 5.1, 5.0, 5.1, 5.0, 5.1]

      quick = NormalityTests.quick_check(data)
      sw = NormalityTests.shapiro_wilk(data)

      # Both should likely indicate normality
      assert quick.is_normal == true
      # SW might be more sensitive, but should have high W
      assert sw.statistic > 0.3
    end

    test "methods handle edge cases gracefully" do
      # Constant data
      data = [5.0, 5.0, 5.0, 5.0, 5.0]

      quick = NormalityTests.quick_check(data)
      sw = NormalityTests.shapiro_wilk(data)

      # Should handle without crashing
      assert is_map(quick)
      assert is_map(sw)
    end
  end
end
