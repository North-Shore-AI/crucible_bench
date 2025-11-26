defmodule CrucibleBench.Stats.MultipleComparisons do
  @moduledoc """
  Multiple comparison correction methods for controlling Type I error rates.

  When conducting multiple hypothesis tests, the probability of at least one
  false positive increases. These methods adjust p-values to control either:

  - **Family-Wise Error Rate (FWER)**: Probability of at least one false positive
  - **False Discovery Rate (FDR)**: Expected proportion of false positives among rejections

  ## Methods

  - **Bonferroni**: Most conservative, controls FWER
  - **Holm**: Less conservative than Bonferroni, still controls FWER
  - **Benjamini-Hochberg**: Controls FDR, more powerful for exploratory research

  ## References

  - Bonferroni, C. E. (1936). "Teoria statistica delle classi e calcolo delle probabilità"
  - Holm, S. (1979). "A simple sequentially rejective multiple test procedure"
  - Benjamini, Y., & Hochberg, Y. (1995). "Controlling the false discovery rate"
  """

  @doc """
  Apply Bonferroni correction to p-values.

  The most conservative method. Adjusts each p-value by multiplying by the
  number of tests. Controls family-wise error rate (FWER).

  **Formula**: p_adjusted = min(p_original × n, 1.0)

  ## Examples

      iex> p_values = [0.01, 0.03, 0.04, 0.20]
      iex> CrucibleBench.Stats.MultipleComparisons.bonferroni(p_values)
      [0.04, 0.12, 0.16, 0.80]

      iex> # With very small p-values
      iex> p_values = [0.001, 0.002]
      iex> CrucibleBench.Stats.MultipleComparisons.bonferroni(p_values)
      [0.002, 0.004]
  """
  def bonferroni([]), do: []

  def bonferroni(p_values) when is_list(p_values) do
    n = length(p_values)

    Enum.map(p_values, fn p ->
      min(p * n, 1.0)
    end)
  end

  @doc """
  Apply Holm's step-down method.

  Less conservative than Bonferroni while still controlling FWER.
  Uniformly more powerful than Bonferroni. Tests are rejected in order
  from smallest to largest p-value, with adjustment decreasing.

  **Algorithm**:
  1. Sort p-values in ascending order
  2. For the i-th smallest p-value: p_adjusted = p × (n - i + 1)
  3. Enforce monotonicity: adjusted p-values should be non-decreasing

  ## Examples

      iex> p_values = [0.01, 0.03, 0.04, 0.20]
      iex> CrucibleBench.Stats.MultipleComparisons.holm(p_values)
      [0.04, 0.09, 0.09, 0.20]
  """
  def holm([]), do: []

  def holm(p_values) when is_list(p_values) do
    n = length(p_values)

    # Create indexed list to track original order
    indexed = Enum.with_index(p_values, 0)

    # Sort by p-value (ascending)
    sorted = Enum.sort_by(indexed, fn {p, _idx} -> p end)

    # Apply Holm correction with cumulative max for monotonicity
    adjusted =
      sorted
      |> Enum.with_index(1)
      |> Enum.map_reduce(0, fn {{p, original_idx}, rank}, max_so_far ->
        # Holm adjustment: p × (n - rank + 1)
        adjusted_p = min(p * (n - rank + 1), 1.0)
        # Enforce monotonicity
        final_p = max(adjusted_p, max_so_far)
        {{original_idx, final_p}, final_p}
      end)
      |> elem(0)
      |> Enum.sort_by(fn {idx, _p} -> idx end)
      |> Enum.map(fn {_idx, p} -> p end)

    adjusted
  end

  @doc """
  Apply Benjamini-Hochberg FDR correction.

  Controls False Discovery Rate (FDR) rather than Family-Wise Error Rate.
  More powerful than Bonferroni/Holm for exploratory research where some
  false positives are acceptable.

  **Algorithm**:
  1. Sort p-values in ascending order
  2. For the i-th smallest p-value: p_adjusted = p × n / i
  3. Enforce monotonicity: adjusted should be non-decreasing

  ## Options

  - `:fdr_level` - Target false discovery rate (default: 0.05)

  ## Examples

      iex> p_values = [0.01, 0.03, 0.04, 0.20]
      iex> CrucibleBench.Stats.MultipleComparisons.benjamini_hochberg(p_values)
      [0.04, 0.05333333333333334, 0.05333333333333334, 0.20]

      iex> # With custom FDR level
      iex> p_values = [0.01, 0.03]
      iex> CrucibleBench.Stats.MultipleComparisons.benjamini_hochberg(p_values, fdr_level: 0.10)
      [0.02, 0.03]
  """
  def benjamini_hochberg(p_values, opts \\ [])
  def benjamini_hochberg([], _opts), do: []

  def benjamini_hochberg(p_values, opts) when is_list(p_values) do
    _fdr_level = Keyword.get(opts, :fdr_level, 0.05)
    n = length(p_values)

    # Create indexed list to track original order
    indexed = Enum.with_index(p_values, 0)

    # Sort by p-value (ascending)
    sorted = Enum.sort_by(indexed, fn {p, _idx} -> p end)

    # Apply BH correction (need to go in reverse for monotonicity)
    adjusted =
      sorted
      |> Enum.with_index(1)
      |> Enum.map(fn {{p, original_idx}, rank} ->
        # BH adjustment: p × n / rank
        adjusted_p = min(p * n / rank, 1.0)
        {original_idx, rank, adjusted_p}
      end)
      |> Enum.reverse()
      |> Enum.reduce([], fn {original_idx, _rank, adjusted_p}, acc ->
        case acc do
          [] ->
            [{original_idx, adjusted_p}]

          [{_, prev_p} | _] ->
            # Enforce monotonicity: no adjusted p should be larger than those with larger original p
            final_p = min(adjusted_p, prev_p)
            [{original_idx, final_p} | acc]
        end
      end)
      |> Enum.sort_by(fn {idx, _p} -> idx end)
      |> Enum.map(fn {_idx, p} -> p end)

    adjusted
  end

  @doc """
  Apply correction and return detailed results.

  Returns a list of maps with comprehensive information about each test.

  ## Options

  - `:method` - :bonferroni, :holm, or :benjamini_hochberg (default: :holm)
  - `:alpha` - Significance level for reporting (default: 0.05)
  - `:fdr_level` - For Benjamini-Hochberg only (default: 0.05)

  ## Examples

      iex> p_values = [0.01, 0.03, 0.04, 0.20]
      iex> results = CrucibleBench.Stats.MultipleComparisons.correct(p_values)
      iex> Enum.at(results, 0).original_p_value
      0.01

      iex> p_values = [0.01, 0.03]
      iex> results = CrucibleBench.Stats.MultipleComparisons.correct(p_values, method: :bonferroni)
      iex> Enum.at(results, 0).method
      :bonferroni
  """
  def correct(p_values, opts \\ []) when is_list(p_values) do
    method = Keyword.get(opts, :method, :holm)

    alpha =
      case method do
        :benjamini_hochberg -> Keyword.get(opts, :fdr_level, Keyword.get(opts, :alpha, 0.05))
        _ -> Keyword.get(opts, :alpha, 0.05)
      end

    adjusted =
      case method do
        :bonferroni -> bonferroni(p_values)
        :holm -> holm(p_values)
        :benjamini_hochberg -> benjamini_hochberg(p_values, opts)
        _ -> raise ArgumentError, "Unknown correction method: #{method}"
      end

    Enum.zip([p_values, adjusted])
    |> Enum.with_index(1)
    |> Enum.map(fn {{original_p, adjusted_p}, test_number} ->
      %{
        test_number: test_number,
        original_p_value: original_p,
        adjusted_p_value: adjusted_p,
        significant_original: original_p < alpha,
        significant_adjusted: adjusted_p < alpha,
        method: method,
        alpha: alpha
      }
    end)
  end

  @doc """
  Calculate the effective alpha level after Bonferroni correction.

  When using Bonferroni correction, each individual test uses a more
  stringent alpha level to maintain overall family-wise error rate.

  ## Examples

      iex> # With 10 tests and α = 0.05, each test uses α = 0.005
      iex> CrucibleBench.Stats.MultipleComparisons.bonferroni_alpha(10, 0.05)
      0.005

      iex> CrucibleBench.Stats.MultipleComparisons.bonferroni_alpha(3, 0.05)
      0.016666666666666666
  """
  def bonferroni_alpha(n_tests, family_wise_alpha \\ 0.05) do
    family_wise_alpha / n_tests
  end

  @doc """
  Determine which hypotheses to reject using a correction method.

  Returns a list of booleans indicating which tests reject the null hypothesis.

  ## Examples

      iex> p_values = [0.001, 0.01, 0.03, 0.20]
      iex> CrucibleBench.Stats.MultipleComparisons.reject(p_values, method: :bonferroni)
      [true, true, false, false]

      iex> p_values = [0.001, 0.01, 0.03, 0.20]
      iex> CrucibleBench.Stats.MultipleComparisons.reject(p_values, method: :holm)
      [true, true, false, false]
  """
  def reject(p_values, opts \\ []) do
    method = Keyword.get(opts, :method, :holm)

    alpha =
      case method do
        :benjamini_hochberg -> Keyword.get(opts, :fdr_level, Keyword.get(opts, :alpha, 0.05))
        _ -> Keyword.get(opts, :alpha, 0.05)
      end

    results = correct(p_values, opts)

    Enum.map(results, fn result ->
      result.adjusted_p_value < alpha
    end)
  end
end
