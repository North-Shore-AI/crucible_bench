defmodule CrucibleBench.Analysis do
  @moduledoc """
  High-level analysis functions with automatic test selection.

  Provides smart defaults and automatic assumption checking.
  """

  alias CrucibleBench.Stats

  alias CrucibleBench.Stats.{
    TTest,
    PairedTTest,
    ANOVA,
    MannWhitney,
    Wilcoxon,
    KruskalWallis,
    EffectSize
  }

  @doc """
  Compare two independent groups with automatic test selection.

  Automatically checks assumptions and selects appropriate test:
  - Normal data + equal variance: Student's t-test
  - Normal data + unequal variance: Welch's t-test (default)
  - Non-normal data: Mann-Whitney U test

  ## Options

  - `:test` - Force specific test (:t_test, :welch_t_test, :mann_whitney)
  - `:confidence_level` - Confidence level for CI (default: 0.95)
  - `:check_assumptions` - Test normality (default: true)
  - `:alternative` - :two_sided (default), :less, :greater
  """
  def compare_groups(group1, group2, opts \\ []) do
    forced_test = Keyword.get(opts, :test)
    check_assumptions = Keyword.get(opts, :check_assumptions, true)

    test_to_use =
      if forced_test do
        forced_test
      else
        if check_assumptions and not normal_enough?(group1, group2) do
          :mann_whitney
        else
          :welch_t_test
        end
      end

    result =
      case test_to_use do
        :t_test -> TTest.test(group1, group2, Keyword.put(opts, :var_equal, true))
        :welch_t_test -> TTest.test(group1, group2, Keyword.put(opts, :var_equal, false))
        :mann_whitney -> MannWhitney.test(group1, group2, opts)
        _ -> raise ArgumentError, "Unknown test: #{test_to_use}"
      end

    # Add effect size if not non-parametric
    result =
      if test_to_use in [:t_test, :welch_t_test] do
        effect = EffectSize.cohens_d(group1, group2)
        %{result | effect_size: effect}
      else
        result
      end

    result
  end

  @doc """
  Compare paired groups with automatic test selection.

  Selects paired t-test for normal differences, Wilcoxon for non-normal.
  """
  def compare_paired(group1, group2, opts \\ []) do
    forced_test = Keyword.get(opts, :test)
    check_assumptions = Keyword.get(opts, :check_assumptions, true)

    differences = Enum.zip_with(group1, group2, fn x, y -> y - x end)

    test_to_use =
      if forced_test do
        forced_test
      else
        if check_assumptions and not normal_enough?(differences) do
          :wilcoxon
        else
          :paired_t_test
        end
      end

    result =
      case test_to_use do
        :paired_t_test -> PairedTTest.test(group1, group2, opts)
        :wilcoxon -> Wilcoxon.test(group1, group2, opts)
        _ -> raise ArgumentError, "Unknown test: #{test_to_use}"
      end

    # Add effect size for parametric test
    result =
      if test_to_use == :paired_t_test do
        effect = EffectSize.paired_cohens_d(group1, group2)
        %{result | effect_size: effect}
      else
        result
      end

    result
  end

  @doc """
  Compare multiple groups with automatic test selection.

  Selects ANOVA for normal data with equal variances,
  Kruskal-Wallis for non-normal data.
  """
  def compare_multiple(groups, opts \\ []) when is_list(groups) do
    unless length(groups) >= 2 do
      raise ArgumentError, "Need at least 2 groups"
    end

    forced_test = Keyword.get(opts, :test)
    check_assumptions = Keyword.get(opts, :check_assumptions, true)

    test_to_use =
      if forced_test do
        forced_test
      else
        if check_assumptions and not all_normal?(groups) do
          :kruskal_wallis
        else
          :anova
        end
      end

    case test_to_use do
      :anova -> ANOVA.one_way(groups, opts)
      :kruskal_wallis -> KruskalWallis.test(groups, opts)
      _ -> raise ArgumentError, "Unknown test: #{test_to_use}"
    end
  end

  # Simple normality check using skewness and kurtosis
  defp normal_enough?(data) when is_list(data) do
    n = length(data)

    if n < 8 do
      # Too small for reliable normality test, assume normal
      true
    else
      skew = Stats.skewness(data)
      kurt = Stats.kurtosis(data)

      # Rough guidelines: |skew| < 2 and |kurt| < 7 suggests normality
      skew_ok = skew == nil or abs(skew) < 2.0
      kurt_ok = kurt == nil or abs(kurt) < 7.0

      skew_ok and kurt_ok
    end
  end

  defp normal_enough?(group1, group2) do
    normal_enough?(group1) and normal_enough?(group2)
  end

  defp all_normal?(groups) do
    Enum.all?(groups, &normal_enough?/1)
  end
end
