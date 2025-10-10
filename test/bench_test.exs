defmodule BenchTest do
  use ExUnit.Case
  doctest CrucibleBench

  describe "compare/2" do
    test "compares two independent groups" do
      control = [5.1, 4.9, 5.3, 5.0, 5.2]
      treatment = [6.2, 6.0, 6.4, 5.9, 6.1]

      result = CrucibleBench.compare(control, treatment)

      assert result.p_value < 0.05
      assert result.test in [:welch_t_test, :student_t_test]
      assert is_map(result.effect_size)
      assert is_tuple(result.confidence_interval)
    end

    test "handles equal groups" do
      group1 = [5.0, 5.1, 5.0, 5.1, 5.0]
      group2 = [5.0, 5.1, 5.0, 5.1, 5.0]

      result = CrucibleBench.compare(group1, group2)

      assert result.p_value > 0.05
    end
  end

  describe "compare_paired/2" do
    test "compares paired groups" do
      before = [0.72, 0.68, 0.75, 0.71, 0.69]
      after_data = [0.78, 0.73, 0.81, 0.76, 0.74]

      result = CrucibleBench.compare_paired(before, after_data)

      assert result.p_value < 0.05
      assert result.test in [:paired_t_test, :wilcoxon]
      assert is_number(result.statistic)
    end

    test "requires equal length groups" do
      before = [0.72, 0.68, 0.75]
      after_data = [0.78, 0.73]

      assert_raise ArgumentError, fn ->
        CrucibleBench.compare_paired(before, after_data)
      end
    end
  end

  describe "compare_multiple/1" do
    test "compares multiple groups" do
      group1 = [10.0, 11.0, 9.0, 10.5, 10.2]
      group2 = [5.0, 6.0, 4.5, 5.5, 5.2]
      group3 = [1.0, 2.0, 0.5, 1.5, 1.2]

      result = CrucibleBench.compare_multiple([group1, group2, group3])

      assert result.p_value < 0.05
      assert result.test in [:anova, :kruskal_wallis]
      assert is_map(result.effect_size)
    end
  end

  describe "effect_size/2" do
    test "calculates Cohen's d" do
      group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      group2 = [6.0, 6.2, 5.8, 6.1, 5.9]

      effect = CrucibleBench.effect_size(group1, group2)

      assert is_map(effect)
      assert Map.has_key?(effect, :cohens_d)
      assert is_binary(effect.interpretation)
    end
  end

  describe "confidence_interval/2" do
    test "calculates CI for mean" do
      data = [5.0, 5.2, 4.8, 5.1, 4.9, 5.3]

      ci = CrucibleBench.confidence_interval(data, :mean)

      assert is_map(ci)
      assert Map.has_key?(ci, :interval)
      {lower, upper} = ci.interval
      assert lower < upper
    end
  end

  describe "power_analysis/2" do
    test "calculates required sample size (a priori)" do
      result =
        CrucibleBench.power_analysis(:t_test,
          analysis_type: :a_priori,
          effect_size: 0.5,
          alpha: 0.05,
          power: 0.80
        )

      assert result.n_per_group > 0
      assert result.analysis_type == :a_priori
    end

    test "calculates achieved power (post-hoc)" do
      result =
        CrucibleBench.power_analysis(:t_test,
          analysis_type: :post_hoc,
          effect_size: 0.5,
          n_per_group: 64,
          alpha: 0.05
        )

      assert result.power > 0
      assert result.power <= 1.0
      assert result.analysis_type == :post_hoc
    end
  end

  describe "experiment/2" do
    test "runs A/B test experiment" do
      control = [0.72, 0.68, 0.75, 0.71, 0.69]
      treatment = [0.78, 0.73, 0.81, 0.76, 0.74]

      result =
        CrucibleBench.experiment(:ab_test,
          control: control,
          treatment: treatment,
          name: "Test Experiment"
        )

      assert result.experiment_type == :ab_test
      assert is_boolean(result.significant?)
      assert is_map(result.effect_size)
      assert is_binary(result.interpretation)
    end

    test "runs ablation experiment" do
      baseline = [0.85, 0.87, 0.84, 0.86, 0.88]
      without = [0.78, 0.76, 0.79, 0.77, 0.75]

      result =
        CrucibleBench.experiment(:ablation,
          baseline: baseline,
          without_component: without,
          component_name: "Test Component"
        )

      assert result.experiment_type == :ablation
      assert is_boolean(result.significant_impact?)
      assert is_map(result.performance_drop)
    end

    test "runs hyperparameter sweep" do
      config1 = [0.85, 0.87, 0.84]
      config2 = [0.88, 0.90, 0.89]
      config3 = [0.82, 0.84, 0.83]

      result =
        CrucibleBench.experiment(:hyperparameter_sweep,
          configurations: [config1, config2, config3],
          labels: ["Config A", "Config B", "Config C"]
        )

      assert result.experiment_type == :hyperparameter_sweep
      assert result.configurations_tested == 3
      assert is_map(result.best_configuration)
      assert is_list(result.pairwise_comparisons)
    end
  end
end
