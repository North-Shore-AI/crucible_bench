defmodule CrucibleBench.Stats.EffectSize do
  @moduledoc """
  Effect size measures for statistical tests.

  Effect sizes quantify the magnitude of differences, providing
  practical significance beyond p-values.
  """

  alias CrucibleBench.Stats

  @doc """
  Calculate Cohen's d for two independent groups.

  Cohen's d is the standardized mean difference:
  d = (mean1 - mean2) / pooled_sd

  Interpretation (Cohen, 1988):
  - Small: |d| = 0.2
  - Medium: |d| = 0.5
  - Large: |d| = 0.8

  ## Examples

      iex> group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      iex> group2 = [6.0, 6.2, 5.8, 6.1, 5.9]
      iex> result = CrucibleBench.Stats.EffectSize.cohens_d(group1, group2)
      iex> result.cohens_d > 0
      true
  """
  def cohens_d(group1, group2) do
    mean1 = Stats.mean(group1)
    mean2 = Stats.mean(group2)
    var1 = Stats.variance(group1)
    var2 = Stats.variance(group2)

    # Pooled standard deviation
    pooled_sd = :math.sqrt((var1 + var2) / 2)

    d = (mean1 - mean2) / pooled_sd

    %{
      cohens_d: d,
      interpretation: interpret_cohens_d(d),
      mean1: mean1,
      mean2: mean2,
      pooled_sd: pooled_sd
    }
  end

  @doc """
  Calculate Hedges' g (bias-corrected Cohen's d).

  Hedges' g applies a correction factor for small sample sizes,
  making it less biased than Cohen's d.

  ## Examples

      iex> group1 = [5.0, 5.2, 4.8]
      iex> group2 = [6.0, 6.2, 5.8]
      iex> result = CrucibleBench.Stats.EffectSize.hedges_g(group1, group2)
      iex> result.hedges_g > 0
      true
  """
  def hedges_g(group1, group2) do
    n1 = length(group1)
    n2 = length(group2)
    n = n1 + n2

    # Calculate Cohen's d first
    cohens = cohens_d(group1, group2)
    d = cohens.cohens_d

    # Correction factor
    correction = 1 - 3 / (4 * n - 9)
    g = d * correction

    %{
      hedges_g: g,
      cohens_d: d,
      correction_factor: correction,
      interpretation: interpret_cohens_d(g)
    }
  end

  @doc """
  Calculate Glass's delta.

  Uses only the control group's standard deviation,
  useful when groups have different variances.

  ## Examples

      iex> control = [5.0, 5.2, 4.8, 5.1, 4.9]
      iex> treatment = [6.0, 6.5, 5.5, 6.2, 5.8]
      iex> result = CrucibleBench.Stats.EffectSize.glass_delta(control, treatment)
      iex> result.glass_delta > 0
      true
  """
  def glass_delta(control, treatment) do
    mean_control = Stats.mean(control)
    mean_treatment = Stats.mean(treatment)
    sd_control = Stats.stdev(control)

    delta = (mean_treatment - mean_control) / sd_control

    %{
      glass_delta: delta,
      interpretation: interpret_cohens_d(delta),
      mean_control: mean_control,
      mean_treatment: mean_treatment,
      sd_control: sd_control
    }
  end

  @doc """
  Calculate effect size for paired data.

  Returns Cohen's d for paired samples, using the standard deviation
  of the differences.

  ## Examples

      iex> before = [0.72, 0.68, 0.75, 0.71, 0.69]
      iex> after_values = [0.78, 0.73, 0.81, 0.76, 0.74]
      iex> result = CrucibleBench.Stats.EffectSize.paired_cohens_d(before, after_values)
      iex> result.cohens_d > 0
      true
  """
  def paired_cohens_d(group1, group2) do
    unless length(group1) == length(group2) do
      raise ArgumentError, "Paired effect size requires equal length groups"
    end

    differences = Enum.zip_with(group1, group2, fn x, y -> y - x end)
    mean_diff = Stats.mean(differences)
    sd_diff = Stats.stdev(differences)

    d = if sd_diff == 0, do: 0.0, else: mean_diff / sd_diff

    %{
      cohens_d: d,
      interpretation: interpret_cohens_d(d),
      mean_diff: mean_diff,
      sd_diff: sd_diff
    }
  end

  @doc """
  General effect size calculation with automatic method selection.

  ## Options

  - `:type` - :cohens_d (default), :hedges_g, :glass_delta
  - `:paired` - true for paired data (default: false)

  ## Examples

      iex> group1 = [5.0, 5.2, 4.8, 5.1, 4.9]
      iex> group2 = [6.0, 6.2, 5.8, 6.1, 5.9]
      iex> result = CrucibleBench.Stats.EffectSize.calculate(group1, group2)
      iex> Map.has_key?(result, :cohens_d)
      true
  """
  def calculate(group1, group2, opts \\ []) do
    paired = Keyword.get(opts, :paired, false)
    type = Keyword.get(opts, :type, :cohens_d)

    if paired do
      paired_cohens_d(group1, group2)
    else
      case type do
        :cohens_d -> cohens_d(group1, group2)
        :hedges_g -> hedges_g(group1, group2)
        :glass_delta -> glass_delta(group1, group2)
        _ -> raise ArgumentError, "Unknown effect size type: #{type}"
      end
    end
  end

  defp interpret_cohens_d(d) do
    abs_d = abs(d)

    cond do
      abs_d < 0.2 -> "negligible"
      abs_d < 0.5 -> "small"
      abs_d < 0.8 -> "medium"
      true -> "large"
    end
  end
end
