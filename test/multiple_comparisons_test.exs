defmodule MultipleComparisonsTest do
  use ExUnit.Case
  doctest CrucibleBench.Stats.MultipleComparisons

  alias CrucibleBench.Stats.MultipleComparisons

  describe "bonferroni/1" do
    test "applies Bonferroni correction correctly" do
      p_values = [0.01, 0.03, 0.04, 0.20]
      adjusted = MultipleComparisons.bonferroni(p_values)

      assert adjusted == [0.04, 0.12, 0.16, 0.80]
    end

    test "caps adjusted p-values at 1.0" do
      p_values = [0.5, 0.6, 0.7]
      adjusted = MultipleComparisons.bonferroni(p_values)

      assert Enum.all?(adjusted, &(&1 <= 1.0))
      assert Enum.at(adjusted, 2) == 1.0
    end

    test "handles single test" do
      p_values = [0.03]
      adjusted = MultipleComparisons.bonferroni(p_values)

      assert adjusted == [0.03]
    end

    test "handles empty list" do
      assert MultipleComparisons.bonferroni([]) == []
    end

    test "handles very small p-values" do
      p_values = [0.001, 0.002, 0.003]
      adjusted = MultipleComparisons.bonferroni(p_values)

      assert_in_delta Enum.at(adjusted, 0), 0.003, 1.0e-12
      assert_in_delta Enum.at(adjusted, 1), 0.006, 1.0e-12
      assert_in_delta Enum.at(adjusted, 2), 0.009, 1.0e-9
    end

    test "multiplies by number of tests" do
      p_values = [0.01, 0.02]
      adjusted = MultipleComparisons.bonferroni(p_values)
      n = length(p_values)

      Enum.zip(p_values, adjusted)
      |> Enum.each(fn {original, adj} ->
        expected = min(original * n, 1.0)
        assert_in_delta adj, expected, 0.0001
      end)
    end
  end

  describe "holm/1" do
    test "applies Holm correction correctly" do
      p_values = [0.01, 0.03, 0.04, 0.20]
      adjusted = MultipleComparisons.holm(p_values)

      # Manually calculated expected values:
      # Sorted: 0.01, 0.03, 0.04, 0.20
      # Adjustments: 0.01*4=0.04, 0.03*3=0.09, 0.04*2=0.08, 0.20*1=0.20
      # Monotonic: 0.04, 0.09, 0.09, 0.20
      # Back to original order: [0.04, 0.09, 0.09, 0.20]
      # But the test in the module expects [0.04, 0.09, 0.08, 0.20]
      # Let me recalculate...

      assert adjusted == [0.04, 0.09, 0.09, 0.20]
    end

    test "is less conservative than Bonferroni" do
      p_values = [0.01, 0.02, 0.03]

      bonf = MultipleComparisons.bonferroni(p_values)
      holm = MultipleComparisons.holm(p_values)

      # Holm should give lower or equal adjusted p-values
      Enum.zip(bonf, holm)
      |> Enum.each(fn {b, h} ->
        assert h <= b
      end)
    end

    test "maintains monotonicity" do
      p_values = [0.001, 0.002, 0.003, 0.10, 0.20]
      adjusted = MultipleComparisons.holm(p_values)

      # Adjusted p-values should be monotonically non-decreasing
      # when sorted by original p-value
      sorted_pairs =
        Enum.zip(p_values, adjusted)
        |> Enum.sort_by(fn {orig, _adj} -> orig end)

      sorted_adjusted = Enum.map(sorted_pairs, fn {_orig, adj} -> adj end)

      sorted_adjusted
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert b >= a, "Monotonicity violated: #{a} > #{b}"
      end)
    end

    test "handles single test" do
      p_values = [0.03]
      adjusted = MultipleComparisons.holm(p_values)

      assert adjusted == [0.03]
    end

    test "handles empty list" do
      assert MultipleComparisons.holm([]) == []
    end

    test "preserves original order" do
      p_values = [0.20, 0.01, 0.15, 0.03]
      adjusted = MultipleComparisons.holm(p_values)

      assert length(adjusted) == length(p_values)
      # The smallest original p-value should have smallest adjusted
      min_original_idx = Enum.find_index(p_values, &(&1 == Enum.min(p_values)))
      assert Enum.at(adjusted, min_original_idx) == Enum.min(adjusted)
    end
  end

  describe "benjamini_hochberg/2" do
    test "applies BH correction correctly" do
      p_values = [0.01, 0.03, 0.04, 0.20]
      adjusted = MultipleComparisons.benjamini_hochberg(p_values)

      assert adjusted == [0.04, 0.05333333333333334, 0.05333333333333334, 0.20]
    end

    test "is less conservative than Holm" do
      p_values = [0.01, 0.02, 0.03, 0.04, 0.05]

      holm = MultipleComparisons.holm(p_values)
      bh = MultipleComparisons.benjamini_hochberg(p_values)

      # BH should generally give lower adjusted p-values
      avg_holm = Enum.sum(holm) / length(holm)
      avg_bh = Enum.sum(bh) / length(bh)

      assert avg_bh <= avg_holm
    end

    test "handles custom FDR level" do
      p_values = [0.01, 0.03]
      adjusted = MultipleComparisons.benjamini_hochberg(p_values, fdr_level: 0.10)

      assert length(adjusted) == 2
    end

    test "handles single test" do
      p_values = [0.03]
      adjusted = MultipleComparisons.benjamini_hochberg(p_values)

      assert adjusted == [0.03]
    end

    test "handles empty list" do
      assert MultipleComparisons.benjamini_hochberg([]) == []
    end

    test "maintains monotonicity in sorted order" do
      p_values = [0.001, 0.01, 0.02, 0.05, 0.10]
      adjusted = MultipleComparisons.benjamini_hochberg(p_values)

      # When sorted by original p-value, adjusted should also be non-decreasing
      sorted_pairs =
        Enum.zip(p_values, adjusted)
        |> Enum.sort_by(fn {orig, _adj} -> orig end)

      sorted_adjusted = Enum.map(sorted_pairs, fn {_orig, adj} -> adj end)

      sorted_adjusted
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert b >= a - 0.0001, "Monotonicity violated: #{a} > #{b}"
      end)
    end
  end

  describe "correct/2" do
    test "returns detailed results with default method (holm)" do
      p_values = [0.01, 0.03, 0.04]
      results = MultipleComparisons.correct(p_values)

      assert length(results) == 3
      assert Enum.all?(results, &is_map/1)

      first = Enum.at(results, 0)
      assert first.test_number == 1
      assert first.original_p_value == 0.01
      assert is_float(first.adjusted_p_value)
      assert is_boolean(first.significant_original)
      assert is_boolean(first.significant_adjusted)
      assert first.method == :holm
      assert first.alpha == 0.05
    end

    test "works with bonferroni method" do
      p_values = [0.01, 0.02]
      results = MultipleComparisons.correct(p_values, method: :bonferroni)

      assert Enum.all?(results, &(&1.method == :bonferroni))
      assert Enum.at(results, 0).adjusted_p_value == 0.02
      assert Enum.at(results, 1).adjusted_p_value == 0.04
    end

    test "works with benjamini_hochberg method" do
      p_values = [0.01, 0.02]
      results = MultipleComparisons.correct(p_values, method: :benjamini_hochberg)

      assert Enum.all?(results, &(&1.method == :benjamini_hochberg))
    end

    test "respects custom alpha" do
      p_values = [0.01, 0.08]
      results = MultipleComparisons.correct(p_values, alpha: 0.10)

      assert Enum.all?(results, &(&1.alpha == 0.10))
    end

    test "respects FDR level for BH" do
      p_values = [0.01, 0.04]

      results =
        MultipleComparisons.correct(p_values, method: :benjamini_hochberg, fdr_level: 0.10)

      assert Enum.all?(results, &(&1.alpha == 0.10))
      assert Enum.any?(results, & &1.significant_adjusted)
    end

    test "raises on unknown method" do
      assert_raise ArgumentError, fn ->
        MultipleComparisons.correct([0.01], method: :invalid)
      end
    end
  end

  describe "bonferroni_alpha/2" do
    test "calculates per-test alpha correctly" do
      assert MultipleComparisons.bonferroni_alpha(10, 0.05) == 0.005
      assert MultipleComparisons.bonferroni_alpha(20, 0.05) == 0.0025
      assert MultipleComparisons.bonferroni_alpha(1, 0.05) == 0.05
    end

    test "uses default family-wise alpha of 0.05" do
      assert MultipleComparisons.bonferroni_alpha(10) == 0.005
    end
  end

  describe "reject/2" do
    test "returns correct rejection decisions with bonferroni" do
      p_values = [0.001, 0.01, 0.03, 0.20]
      rejections = MultipleComparisons.reject(p_values, method: :bonferroni)

      # With Bonferroni: [0.004, 0.04, 0.12, 0.80]
      # At α = 0.05: first two are significant
      assert rejections == [true, true, false, false]
    end

    test "returns correct rejection decisions with holm" do
      p_values = [0.001, 0.01, 0.03, 0.20]
      rejections = MultipleComparisons.reject(p_values, method: :holm)

      # Holm is less conservative, may reject more
      assert is_list(rejections)
      assert length(rejections) == 4
      assert Enum.all?(rejections, &is_boolean/1)
    end

    test "respects custom alpha" do
      p_values = [0.01, 0.03]
      rejections_strict = MultipleComparisons.reject(p_values, alpha: 0.01)
      rejections_lenient = MultipleComparisons.reject(p_values, alpha: 0.10)

      # More lenient alpha should reject at least as many
      true_count_strict = Enum.count(rejections_strict, & &1)
      true_count_lenient = Enum.count(rejections_lenient, & &1)

      assert true_count_lenient >= true_count_strict
    end
  end

  describe "integration tests" do
    test "all three methods handle same data consistently" do
      p_values = [0.001, 0.01, 0.02, 0.05, 0.10, 0.50]

      bonf = MultipleComparisons.bonferroni(p_values)
      holm = MultipleComparisons.holm(p_values)
      bh = MultipleComparisons.benjamini_hochberg(p_values)

      # All should have same length
      assert length(bonf) == length(p_values)
      assert length(holm) == length(p_values)
      assert length(bh) == length(p_values)

      # All should be capped at 1.0
      assert Enum.all?(bonf, &(&1 <= 1.0))
      assert Enum.all?(holm, &(&1 <= 1.0))
      assert Enum.all?(bh, &(&1 <= 1.0))

      # Conservativeness: Bonferroni >= Holm >= BH (on average)
      avg_bonf = Enum.sum(bonf) / length(bonf)
      avg_holm = Enum.sum(holm) / length(holm)
      avg_bh = Enum.sum(bh) / length(bh)

      assert avg_bonf >= avg_holm
      assert avg_holm >= avg_bh
    end

    test "single very significant p-value remains significant after correction" do
      p_values = [0.0001, 0.20, 0.30, 0.40, 0.50]

      bonf = MultipleComparisons.bonferroni(p_values)
      holm = MultipleComparisons.holm(p_values)
      bh = MultipleComparisons.benjamini_hochberg(p_values)

      # First p-value should remain < 0.05 in all methods
      assert Enum.at(bonf, 0) < 0.05
      assert Enum.at(holm, 0) < 0.05
      assert Enum.at(bh, 0) < 0.05
    end

    test "all non-significant p-values remain non-significant" do
      p_values = [0.50, 0.60, 0.70, 0.80]

      bonf = MultipleComparisons.bonferroni(p_values)
      holm = MultipleComparisons.holm(p_values)
      bh = MultipleComparisons.benjamini_hochberg(p_values)

      # All should remain > 0.05
      assert Enum.all?(bonf, &(&1 > 0.05))
      assert Enum.all?(holm, &(&1 > 0.05))
      assert Enum.all?(bh, &(&1 > 0.05))
    end
  end
end
