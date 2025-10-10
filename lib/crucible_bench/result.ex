defmodule CrucibleBench.Result do
  @moduledoc """
  Standard result structure for statistical tests.

  All statistical tests in Bench return a `CrucibleBench.Result` struct
  containing test statistics, p-values, effect sizes, and interpretations.
  """

  @type t :: %__MODULE__{
          test: atom(),
          statistic: float(),
          p_value: float(),
          effect_size: map() | nil,
          confidence_interval: {float(), float()} | nil,
          interpretation: String.t() | nil,
          metadata: map()
        }

  defstruct [
    :test,
    :statistic,
    :p_value,
    :effect_size,
    :confidence_interval,
    :interpretation,
    metadata: %{}
  ]

  @doc """
  Determine if result is statistically significant at given alpha level.

  ## Examples

      iex> result = %CrucibleBench.Result{p_value: 0.03}
      iex> CrucibleBench.Result.significant?(result, 0.05)
      true

      iex> result = %CrucibleBench.Result{p_value: 0.08}
      iex> CrucibleBench.Result.significant?(result, 0.05)
      false
  """
  def significant?(%__MODULE__{p_value: p_value}, alpha \\ 0.05) do
    p_value < alpha
  end

  @doc """
  Generate human-readable summary of result.
  """
  def summarize(%__MODULE__{} = result) do
    sig_status = if significant?(result), do: "significant", else: "not significant"

    effect_summary =
      if result.effect_size do
        "\nEffect size: #{format_effect_size(result.effect_size)}"
      else
        ""
      end

    ci_summary =
      if result.confidence_interval do
        {lower, upper} = result.confidence_interval
        "\n95% CI: [#{Float.round(lower, 4)}, #{Float.round(upper, 4)}]"
      else
        ""
      end

    """
    Test: #{result.test}
    Statistic: #{Float.round(result.statistic, 4)}
    P-value: #{format_p_value(result.p_value)}
    Result: #{sig_status}#{effect_summary}#{ci_summary}
    """
    |> String.trim()
  end

  defp format_p_value(p) when p < 0.001, do: "< 0.001"
  defp format_p_value(p), do: Float.round(p, 4) |> to_string()

  defp format_effect_size(%{cohens_d: d}), do: "Cohen's d = #{Float.round(d, 3)}"
  defp format_effect_size(%{eta_squared: eta}), do: "η² = #{Float.round(eta, 3)}"
  defp format_effect_size(%{rank_biserial: r}), do: "r = #{Float.round(r, 3)}"
  defp format_effect_size(_), do: "N/A"
end
