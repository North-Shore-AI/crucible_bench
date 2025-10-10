defmodule CrucibleBench.Stats.EffectSizeTest do
  use ExUnit.Case
  alias CrucibleBench.Stats.EffectSize

  describe "cohens_d/2" do
    test "calculates Cohen's d for two groups" do
      # Known example: groups with mean difference of 1 and pooled SD of 1
      group1 = [4.0, 4.5, 5.0, 5.5, 6.0]
      group2 = [5.0, 5.5, 6.0, 6.5, 7.0]

      result = EffectSize.cohens_d(group1, group2)

      assert Map.has_key?(result, :cohens_d)
      assert result.cohens_d < 0
      assert is_binary(result.interpretation)
    end

    test "interprets effect sizes correctly" do
      # Negligible effect - small mean difference relative to spread
      group1 = [4.5, 5.0, 5.5, 6.0, 6.5]
      group2 = [4.6, 5.1, 5.6, 6.1, 6.6]
      result = EffectSize.cohens_d(group1, group2)
      assert result.interpretation == "negligible"

      # Large effect
      group1 = [1.0, 1.5, 2.0, 2.5]
      group2 = [4.0, 4.5, 5.0, 5.5]
      result = EffectSize.cohens_d(group1, group2)
      assert result.interpretation == "large"
    end
  end

  describe "hedges_g/2" do
    test "applies correction for small samples" do
      group1 = [5.0, 5.5, 6.0]
      group2 = [6.0, 6.5, 7.0]

      result = EffectSize.hedges_g(group1, group2)

      assert Map.has_key?(result, :hedges_g)
      assert Map.has_key?(result, :cohens_d)
      assert Map.has_key?(result, :correction_factor)
      # Hedges' g should be slightly smaller than Cohen's d for small samples
      assert abs(result.hedges_g) <= abs(result.cohens_d)
    end
  end

  describe "glass_delta/2" do
    test "uses control group SD only" do
      control = [5.0, 5.2, 4.8, 5.1, 4.9]
      treatment = [6.0, 6.5, 5.5, 6.2, 5.8]

      result = EffectSize.glass_delta(control, treatment)

      assert Map.has_key?(result, :glass_delta)
      assert Map.has_key?(result, :sd_control)
      assert result.glass_delta > 0
    end
  end

  describe "paired_cohens_d/2" do
    test "calculates effect size for paired data" do
      before = [0.72, 0.68, 0.75, 0.71, 0.69]
      after_data = [0.78, 0.73, 0.81, 0.76, 0.74]

      result = EffectSize.paired_cohens_d(before, after_data)

      assert Map.has_key?(result, :cohens_d)
      assert Map.has_key?(result, :mean_diff)
      assert result.cohens_d > 0
    end

    test "requires equal length groups" do
      before = [0.72, 0.68]
      after_data = [0.78]

      assert_raise ArgumentError, fn ->
        EffectSize.paired_cohens_d(before, after_data)
      end
    end
  end

  describe "calculate/3" do
    test "supports different effect size types" do
      group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      group2 = [6.0, 6.2, 5.8, 6.1, 5.9]

      # Cohen's d
      result1 = EffectSize.calculate(group1, group2, type: :cohens_d)
      assert Map.has_key?(result1, :cohens_d)

      # Hedges' g
      result2 = EffectSize.calculate(group1, group2, type: :hedges_g)
      assert Map.has_key?(result2, :hedges_g)

      # Glass's delta
      result3 = EffectSize.calculate(group1, group2, type: :glass_delta)
      assert Map.has_key?(result3, :glass_delta)
    end

    test "supports paired data" do
      group1 = [5.0, 5.2, 4.8]
      group2 = [5.5, 5.7, 5.3]

      result = EffectSize.calculate(group1, group2, paired: true)
      assert Map.has_key?(result, :cohens_d)
      assert Map.has_key?(result, :mean_diff)
    end
  end
end
