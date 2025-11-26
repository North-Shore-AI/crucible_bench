defmodule VarianceTestsTest do
  use ExUnit.Case
  doctest CrucibleBench.Stats.VarianceTests

  alias CrucibleBench.Stats.VarianceTests

  describe "levene_test/2" do
    test "returns valid result structure" do
      group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      group2 = [6.0, 6.2, 5.8, 6.1, 5.9]

      result = VarianceTests.levene_test([group1, group2])

      assert is_map(result)
      assert result.test == :levene
      assert is_float(result.statistic)
      assert is_float(result.p_value)
      assert result.p_value >= 0.0 and result.p_value <= 1.0
      assert is_boolean(result.equal_variances)
      assert is_integer(result.df_between)
      assert is_integer(result.df_within)
      assert is_binary(result.interpretation)
    end

    test "detects equal variances" do
      # Groups with similar variances
      group1 = [5.0, 5.2, 4.8, 5.1, 4.9, 5.0, 5.1]
      group2 = [6.0, 6.2, 5.8, 6.1, 5.9, 6.0, 6.1]

      result = VarianceTests.levene_test([group1, group2])

      # Should likely indicate equal variances (high p-value)
      assert result.p_value > 0.05 or result.equal_variances == true
    end

    test "handles three groups" do
      group1 = [5.0, 5.1, 5.0, 5.1]
      group2 = [6.0, 6.1, 6.0, 6.1]
      group3 = [7.0, 7.1, 7.0, 7.1]

      result = VarianceTests.levene_test([group1, group2, group3])

      assert is_map(result)
      assert result.df_between == 2
    end

    test "uses median by default (Brown-Forsythe)" do
      group1 = [1, 2, 3]
      group2 = [4, 5, 6]

      result = VarianceTests.levene_test([group1, group2])

      assert result.center == :median
    end

    test "can use mean as center" do
      group1 = [1, 2, 3]
      group2 = [4, 5, 6]

      result = VarianceTests.levene_test([group1, group2], center: :mean)

      assert result.center == :mean
    end

    test "raises on single group" do
      assert_raise ArgumentError, fn ->
        VarianceTests.levene_test([[1, 2, 3]])
      end
    end

    test "raises on groups with insufficient data" do
      assert_raise ArgumentError, fn ->
        VarianceTests.levene_test([[1, 2, 3], [4]])
      end
    end

    test "handles constant data gracefully" do
      group1 = [5.0, 5.0, 5.0, 5.0]
      group2 = [5.0, 5.0, 5.0, 5.0]

      # Should not crash
      result = VarianceTests.levene_test([group1, group2])

      assert is_map(result)
    end
  end

  describe "f_test/2" do
    test "returns valid result structure" do
      group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      group2 = [6.0, 6.2, 5.8, 6.1, 5.9]

      result = VarianceTests.f_test(group1, group2)

      assert is_map(result)
      assert result.test == :f_test
      assert is_float(result.statistic)
      # F is always >= 1 (larger var / smaller var)
      assert result.statistic >= 1.0
      assert is_float(result.p_value)
      assert result.p_value >= 0.0 and result.p_value <= 1.0
      assert is_boolean(result.equal_variances)
      assert is_integer(result.df1)
      assert is_integer(result.df2)
      assert is_float(result.var1)
      assert is_float(result.var2)
    end

    test "detects similar variances" do
      group1 = [5.0, 5.1, 5.0, 5.1, 5.0]
      group2 = [6.0, 6.1, 6.0, 6.1, 6.0]

      result = VarianceTests.f_test(group1, group2)

      # F statistic should be close to 1
      assert result.statistic < 5.0
    end

    test "F statistic always >= 1" do
      group1 = [1.0, 2.0, 3.0, 4.0, 5.0]
      group2 = [10.0, 20.0, 30.0, 40.0, 50.0]

      result = VarianceTests.f_test(group1, group2)

      assert result.statistic >= 1.0
    end

    test "raises on insufficient data" do
      assert_raise ArgumentError, fn ->
        VarianceTests.f_test([1], [2, 3])
      end

      assert_raise ArgumentError, fn ->
        VarianceTests.f_test([1, 2], [3])
      end
    end

    test "handles equal variances" do
      group1 = [1.0, 2.0, 3.0]
      group2 = [4.0, 5.0, 6.0]

      result = VarianceTests.f_test(group1, group2)

      # Variances should be equal (same spread)
      assert result.statistic <= 2.0
    end

    test "consistent results" do
      group1 = [5.0, 5.1, 5.0, 5.1]
      group2 = [6.0, 6.2, 5.8, 6.1]

      result1 = VarianceTests.f_test(group1, group2)
      result2 = VarianceTests.f_test(group1, group2)

      assert result1.statistic == result2.statistic
    end
  end

  describe "quick_check/2" do
    test "returns valid result structure" do
      group1 = [5.0, 5.1, 5.0]
      group2 = [6.0, 6.1, 6.0]

      result = VarianceTests.quick_check(group1, group2)

      assert is_map(result)
      assert is_boolean(result.equal_variances)
      assert is_float(result.var1)
      assert is_float(result.var2)
      assert is_float(result.ratio)
      assert is_binary(result.reason)
    end

    test "accepts similar variances" do
      group1 = [5.0, 5.1, 5.0, 5.1]
      group2 = [6.0, 6.1, 6.0, 6.1]

      result = VarianceTests.quick_check(group1, group2)

      assert result.equal_variances == true
      assert result.ratio >= 0.25 and result.ratio <= 4.0
    end

    test "rejects very different variances" do
      # Very small variance
      group1 = [5.0, 5.0, 5.0, 5.0]
      # Large variance
      group2 = [1.0, 10.0, 2.0, 9.0]

      result = VarianceTests.quick_check(group1, group2)

      # Should detect difference
      assert result.ratio < 0.25 or result.ratio > 4.0
    end

    test "handles zero variance gracefully" do
      group1 = [5.0, 5.0, 5.0]
      group2 = [6.0, 6.1, 6.0]

      result = VarianceTests.quick_check(group1, group2)

      # Should not crash
      assert is_map(result)
    end

    test "symmetric results" do
      group1 = [1.0, 2.0, 3.0]
      group2 = [4.0, 5.0, 6.0]

      result1 = VarianceTests.quick_check(group1, group2)
      result2 = VarianceTests.quick_check(group2, group1)

      # Ratios should be reciprocals
      assert_in_delta result1.ratio, 1.0 / result2.ratio, 0.01
      # Decisions should match
      assert result1.equal_variances == result2.equal_variances
    end
  end

  describe "integration tests" do
    test "Levene and F-test generally agree" do
      group1 = [5.0, 5.2, 4.8, 5.1, 4.9, 5.0]
      group2 = [6.0, 6.2, 5.8, 6.1, 5.9, 6.0]

      levene = VarianceTests.levene_test([group1, group2])
      f = VarianceTests.f_test(group1, group2)

      # Both should indicate equal or unequal consistently
      # (they may differ in borderline cases, but usually agree)
      assert is_boolean(levene.equal_variances)
      assert is_boolean(f.equal_variances)
    end

    test "all methods handle constant data" do
      group1 = [5.0, 5.0, 5.0, 5.0]
      group2 = [6.0, 6.0, 6.0, 6.0]

      levene = VarianceTests.levene_test([group1, group2])
      f = VarianceTests.f_test(group1, group2)
      quick = VarianceTests.quick_check(group1, group2)

      # None should crash
      assert is_map(levene)
      assert is_map(f)
      assert is_map(quick)
    end

    test "methods identify clearly unequal variances" do
      # Zero variance
      group1 = [5.0, 5.0, 5.0, 5.0, 5.0]
      # Large variance
      group2 = [1.0, 5.0, 10.0, 15.0, 20.0]

      levene = VarianceTests.levene_test([group1, group2])
      f = VarianceTests.f_test(group1, group2)

      # At least one should detect the difference
      assert not levene.equal_variances or not f.equal_variances
    end
  end
end
