defmodule CrucibleBench.Export do
  @moduledoc """
  Export statistical results to various formats.

  Supports Markdown, LaTeX, and HTML output for publication.
  """

  alias CrucibleBench.Result

  @doc """
  Export result to Markdown format.

  ## Examples

      iex> result = %CrucibleBench.Result{
      ...>   test: :welch_t_test,
      ...>   statistic: 5.477,
      ...>   p_value: 0.001307,
      ...>   confidence_interval: {0.5, 1.5}
      ...> }
      iex> markdown = CrucibleBench.Export.to_markdown(result)
      iex> String.contains?(markdown, "Welch's t-test")
      true
  """
  def to_markdown(%Result{} = result) do
    """
    ## Statistical Test Results

    **Test**: #{format_test_name(result.test)}
    **Test Statistic**: #{format_number(result.statistic)}
    **P-value**: #{format_p_value(result.p_value)}
    **Significance**: #{if result.p_value < 0.05, do: "Yes (p < 0.05)", else: "No (p ≥ 0.05)"}

    #{format_effect_size_md(result.effect_size)}
    #{format_confidence_interval_md(result.confidence_interval)}

    ### Interpretation

    #{result.interpretation || "No interpretation available"}

    #{format_metadata_md(result.metadata)}
    """
    |> String.trim()
  end

  @doc """
  Export result to LaTeX format.

  Generates LaTeX table suitable for academic papers.
  """
  def to_latex(%Result{} = result) do
    """
    \\begin{table}[h]
    \\centering
    \\begin{tabular}{ll}
    \\hline
    \\textbf{Test} & #{format_test_name(result.test)} \\\\
    \\textbf{Test Statistic} & #{format_number(result.statistic)} \\\\
    \\textbf{P-value} & #{format_p_value_latex(result.p_value)} \\\\
    #{format_effect_size_latex(result.effect_size)}
    #{format_confidence_interval_latex(result.confidence_interval)}
    \\hline
    \\end{tabular}
    \\caption{Statistical test results}
    \\label{tab:results}
    \\end{table}
    """
    |> String.trim()
  end

  @doc """
  Export result to HTML format.

  Generates styled HTML suitable for interactive reports.
  """
  def to_html(%Result{} = result) do
    """
    <div class="statistical-results">
      <h2>Statistical Test Results</h2>
      <table class="results-table">
        <tr>
          <th>Test</th>
          <td>#{format_test_name(result.test)}</td>
        </tr>
        <tr>
          <th>Test Statistic</th>
          <td>#{format_number(result.statistic)}</td>
        </tr>
        <tr>
          <th>P-value</th>
          <td class="#{if result.p_value < 0.05, do: "significant", else: "not-significant"}">
            #{format_p_value(result.p_value)}
          </td>
        </tr>
        #{format_effect_size_html(result.effect_size)}
        #{format_confidence_interval_html(result.confidence_interval)}
      </table>

      <div class="interpretation">
        <h3>Interpretation</h3>
        <p>#{result.interpretation || "No interpretation available"}</p>
      </div>

      #{format_metadata_html(result.metadata)}
    </div>

    <style>
      .statistical-results { font-family: Arial, sans-serif; max-width: 800px; margin: 20px; }
      .results-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
      .results-table th { text-align: left; padding: 8px; background-color: #f0f0f0; border: 1px solid #ddd; }
      .results-table td { padding: 8px; border: 1px solid #ddd; }
      .significant { color: #d9534f; font-weight: bold; }
      .not-significant { color: #5bc0de; }
      .interpretation { margin-top: 20px; padding: 15px; background-color: #f9f9f9; border-left: 4px solid #5bc0de; }
      .metadata { margin-top: 20px; font-size: 0.9em; color: #666; }
    </style>
    """
    |> String.trim()
  end

  @doc """
  Export experiment results to comprehensive report.
  """
  def experiment_to_markdown(experiment_result) do
    case experiment_result.experiment_type do
      :ab_test -> ab_test_report(experiment_result)
      :ablation -> ablation_report(experiment_result)
      :hyperparameter_sweep -> sweep_report(experiment_result)
    end
  end

  defp ab_test_report(exp) do
    """
    # A/B Test Report: #{exp.name}

    ## Summary

    #{if exp.significant?, do: "✓", else: "✗"} **Result**: #{if exp.significant?, do: "Significant difference detected", else: "No significant difference"}

    ## Statistics

    - **P-value**: #{format_p_value(exp.p_value)}
    - **Test Used**: #{format_test_name(exp.test_used)}
    - **Effect Size**: #{exp.effect_size.interpretation} (Cohen's d = #{format_number(exp.effect_size.cohens_d)})
    - **Statistical Power**: #{Float.round(exp.power * 100, 1)}%

    ## Sample Sizes

    - Control: #{exp.sample_sizes.control}
    - Treatment: #{exp.sample_sizes.treatment}

    ## Performance Metrics

    | Group | Mean | Difference |
    |-------|------|------------|
    | Control | #{format_number(exp.means.control)} | - |
    | Treatment | #{format_number(exp.means.treatment)} | #{format_diff(exp.means.difference)} |

    ## Confidence Interval (95%)

    #{format_ci_range(exp.confidence_interval)}

    ## Interpretation

    #{exp.interpretation}

    ## Recommendation

    #{exp.recommendation}
    """
    |> String.trim()
  end

  defp ablation_report(exp) do
    """
    # Ablation Study: #{exp.component_name}

    ## Summary

    #{if exp.significant_impact?, do: "✓ Significant impact", else: "✗ No significant impact"}

    ## Statistics

    - **P-value**: #{format_p_value(exp.p_value)}
    - **Effect Size**: #{exp.effect_size.interpretation} (Cohen's d = #{format_number(exp.effect_size.cohens_d)})

    ## Performance Impact

    - **Absolute Drop**: #{format_number(exp.performance_drop.absolute)}
    - **Percent Drop**: #{format_number(exp.performance_drop.percent)}%

    ## Performance Comparison

    | Configuration | Mean Performance |
    |--------------|------------------|
    | Baseline (with component) | #{format_number(exp.means.baseline)} |
    | Without component | #{format_number(exp.means.without_component)} |

    ## Interpretation

    #{exp.interpretation}
    """
    |> String.trim()
  end

  defp sweep_report(exp) do
    """
    # Hyperparameter Sweep Results

    ## Summary

    **Configurations Tested**: #{exp.configurations_tested}
    **Best Configuration**: #{exp.best_configuration.name} (mean = #{format_number(exp.best_configuration.mean)})

    ## Omnibus Test

    - **Significant Differences**: #{if exp.omnibus_test.significant?, do: "Yes", else: "No"}
    - **P-value**: #{format_p_value(exp.omnibus_test.p_value)}
    - **Test Used**: #{format_test_name(exp.omnibus_test.test_used)}
    - **Effect Size**: #{exp.omnibus_test.effect_size.interpretation}

    ## Configuration Means

    | Configuration | Mean Performance |
    |--------------|------------------|
    #{format_config_means(exp.configuration_means)}

    ## Pairwise Comparisons

    **Multiple Comparison Correction**: #{format_correction_method(Map.get(exp, :correction_method, :holm))}

    #{format_pairwise_comparisons(exp.pairwise_comparisons)}

    ## Interpretation

    #{exp.interpretation}
    """
    |> String.trim()
  end

  # Formatting helpers

  defp format_test_name(:welch_t_test), do: "Welch's t-test"
  defp format_test_name(:student_t_test), do: "Student's t-test"
  defp format_test_name(:paired_t_test), do: "Paired t-test"
  defp format_test_name(:anova), do: "One-way ANOVA"
  defp format_test_name(:mann_whitney), do: "Mann-Whitney U test"
  defp format_test_name(:wilcoxon_signed_rank), do: "Wilcoxon signed-rank test"
  defp format_test_name(:kruskal_wallis), do: "Kruskal-Wallis test"
  defp format_test_name(other), do: to_string(other)

  defp format_number(nil), do: "N/A"
  defp format_number(n) when is_float(n), do: Float.round(n, 4) |> to_string()
  defp format_number(n), do: to_string(n)

  defp format_p_value(p) when p < 0.001, do: "< 0.001"
  defp format_p_value(p), do: format_number(p)

  defp format_p_value_latex(p) when p < 0.001, do: "$< 0.001$"
  defp format_p_value_latex(p), do: "$#{format_number(p)}$"

  defp format_diff(d) when d > 0, do: "+#{format_number(d)}"
  defp format_diff(d), do: format_number(d)

  defp format_ci_range({lower, upper}) do
    "[#{format_number(lower)}, #{format_number(upper)}]"
  end

  defp format_ci_range(nil), do: "N/A"

  defp format_effect_size_md(nil), do: ""

  defp format_effect_size_md(effect) when is_map(effect) do
    "**Effect Size**: #{format_effect_size_value(effect)}\n"
  end

  defp format_effect_size_value(%{cohens_d: d}), do: "Cohen's d = #{format_number(d)}"
  defp format_effect_size_value(%{eta_squared: eta}), do: "η² = #{format_number(eta)}"
  defp format_effect_size_value(%{rank_biserial: r}), do: "Rank-biserial r = #{format_number(r)}"
  defp format_effect_size_value(_), do: "N/A"

  defp format_confidence_interval_md(nil), do: ""

  defp format_confidence_interval_md(ci) do
    "**95% Confidence Interval**: #{format_ci_range(ci)}\n"
  end

  defp format_effect_size_latex(nil), do: ""

  defp format_effect_size_latex(effect) when is_map(effect) do
    "\\textbf{Effect Size} & #{format_effect_size_value(effect)} \\\\\n"
  end

  defp format_confidence_interval_latex(nil), do: ""

  defp format_confidence_interval_latex(ci) do
    "\\textbf{95\\% CI} & #{format_ci_range(ci)} \\\\\n"
  end

  defp format_effect_size_html(nil), do: ""

  defp format_effect_size_html(effect) when is_map(effect) do
    """
    <tr>
      <th>Effect Size</th>
      <td>#{format_effect_size_value(effect)}</td>
    </tr>
    """
  end

  defp format_confidence_interval_html(nil), do: ""

  defp format_confidence_interval_html(ci) do
    """
    <tr>
      <th>95% Confidence Interval</th>
      <td>#{format_ci_range(ci)}</td>
    </tr>
    """
  end

  defp format_metadata_md(metadata) when map_size(metadata) == 0, do: ""

  defp format_metadata_md(metadata) do
    """
    ### Additional Details

    #{Enum.map_join(metadata, "\n", fn {k, v} -> "- **#{k}**: #{format_number(v)}" end)}
    """
  end

  defp format_metadata_html(metadata) when map_size(metadata) == 0, do: ""

  defp format_metadata_html(metadata) do
    """
    <div class="metadata">
      <h4>Additional Details</h4>
      <ul>
        #{Enum.map_join(metadata, "\n", fn {k, v} -> "<li><strong>#{k}</strong>: #{format_number(v)}</li>" end)}
      </ul>
    </div>
    """
  end

  defp format_config_means(means) do
    Enum.map_join(means, "\n", fn {name, mean} -> "| #{name} | #{format_number(mean)} |" end)
  end

  defp format_pairwise_comparisons(comparisons) do
    # Check if comparisons have adjusted p-values (new format with corrections)
    has_adjustment =
      comparisons != [] and Map.has_key?(List.first(comparisons), :adjusted_p_value)

    if has_adjustment do
      """
      | Comparison | Original p | Adjusted p | Sig (original) | Sig (adjusted) | Effect Size | Mean Diff |
      |-----------|------------|------------|----------------|----------------|-------------|-----------|
      #{Enum.map_join(comparisons, "\n", &format_pairwise_row_with_adjustment/1)}
      """
    else
      """
      | Comparison | P-value | Significant | Effect Size | Mean Diff |
      |-----------|---------|-------------|-------------|-----------|
      #{Enum.map_join(comparisons, "\n", &format_pairwise_row/1)}
      """
    end
  end

  defp format_pairwise_row(comp) do
    sig = if Map.get(comp, :significant?, false), do: "Yes", else: "No"

    "| #{comp.comparison} | #{format_p_value(comp.p_value)} | #{sig} | #{format_number(comp.effect_size)} | #{format_diff(comp.mean_diff)} |"
  end

  defp format_pairwise_row_with_adjustment(comp) do
    sig_orig = if Map.get(comp, :significant_original, false), do: "Yes", else: "No"
    sig_adj = if Map.get(comp, :significant_adjusted, false), do: "Yes", else: "No"

    "| #{comp.comparison} | #{format_p_value(comp.p_value)} | #{format_p_value(comp.adjusted_p_value)} | #{sig_orig} | #{sig_adj} | #{format_number(comp.effect_size)} | #{format_diff(comp.mean_diff)} |"
  end

  defp format_correction_method(:bonferroni), do: "Bonferroni"
  defp format_correction_method(:holm), do: "Holm step-down"
  defp format_correction_method(:benjamini_hochberg), do: "Benjamini-Hochberg FDR"
  defp format_correction_method(other), do: to_string(other)
end
