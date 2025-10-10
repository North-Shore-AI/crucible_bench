defmodule CrucibleBench.Stats.ConfidenceInterval do
  @moduledoc """
  Confidence interval calculations.

  Supports both analytical and bootstrap methods for various statistics.
  """

  alias CrucibleBench.Stats
  alias CrucibleBench.Stats.Distributions

  @doc """
  Calculate confidence interval for a statistic.

  ## Options

  - `:method` - :analytical (default) or :bootstrap
  - `:confidence_level` - Confidence level (default: 0.95)
  - `:iterations` - Bootstrap iterations (default: 10000)
  - `:seed` - Random seed for reproducibility

  ## Examples

      iex> data = [5.0, 5.2, 4.8, 5.1, 4.9, 5.3]
      iex> ci = CrucibleBench.Stats.ConfidenceInterval.calculate(data, :mean)
      iex> {lower, upper} = ci.interval
      iex> lower < 5.05 and upper > 5.05
      true
  """
  def calculate(data, statistic, opts \\ []) do
    method = Keyword.get(opts, :method, :analytical)
    conf_level = Keyword.get(opts, :confidence_level, 0.95)

    case method do
      :analytical -> analytical_ci(data, statistic, conf_level)
      :bootstrap -> bootstrap_ci(data, statistic, opts)
      _ -> raise ArgumentError, "Unknown method: #{method}"
    end
  end

  @doc """
  Calculate analytical confidence interval for the mean.

  Uses t-distribution for small samples.
  """
  def analytical_ci(data, :mean, conf_level) do
    n = length(data)
    mean = Stats.mean(data)
    sem = Stats.sem(data)
    df = n - 1

    alpha = 1 - conf_level
    t_critical = Distributions.t_quantile(df, 1 - alpha / 2)
    margin = t_critical * sem

    interval = {mean - margin, mean + margin}

    %{
      statistic: :mean,
      point_estimate: mean,
      interval: interval,
      confidence_level: conf_level,
      method: :analytical,
      margin_of_error: margin,
      standard_error: sem
    }
  end

  def analytical_ci(data, :median, conf_level) do
    # For median, use bootstrap (no simple analytical formula)
    bootstrap_ci(data, :median, confidence_level: conf_level)
  end

  def analytical_ci(data, :variance, conf_level) do
    n = length(data)
    var = Stats.variance(data)
    df = n - 1

    alpha = 1 - conf_level

    # Chi-squared based CI for variance
    chi2_lower = chi_squared_quantile(df, alpha / 2)
    chi2_upper = chi_squared_quantile(df, 1 - alpha / 2)

    lower = df * var / chi2_upper
    upper = df * var / chi2_lower

    %{
      statistic: :variance,
      point_estimate: var,
      interval: {lower, upper},
      confidence_level: conf_level,
      method: :analytical
    }
  end

  @doc """
  Calculate bootstrap confidence interval.

  Uses percentile method for bootstrap CI.

  ## Options

  - `:confidence_level` - Confidence level (default: 0.95)
  - `:iterations` - Number of bootstrap samples (default: 10000)
  - `:seed` - Random seed for reproducibility
  """
  def bootstrap_ci(data, statistic, opts \\ []) do
    conf_level = Keyword.get(opts, :confidence_level, 0.95)
    iterations = Keyword.get(opts, :iterations, 10_000)
    seed = Keyword.get(opts, :seed, :os.system_time(:microsecond))

    # Set random seed for reproducibility
    :rand.seed(:exsplus, {seed, seed + 1, seed + 2})

    # Calculate point estimate
    point_estimate = calculate_statistic(data, statistic)

    # Generate bootstrap samples
    bootstrap_stats =
      1..iterations
      |> Enum.map(fn _ ->
        bootstrap_sample = resample(data)
        calculate_statistic(bootstrap_sample, statistic)
      end)
      |> Enum.sort()

    # Percentile method
    alpha = 1 - conf_level
    lower_idx = round(alpha / 2 * iterations)
    upper_idx = round((1 - alpha / 2) * iterations)

    lower = Enum.at(bootstrap_stats, lower_idx)
    upper = Enum.at(bootstrap_stats, upper_idx)

    %{
      statistic: statistic,
      point_estimate: point_estimate,
      interval: {lower, upper},
      confidence_level: conf_level,
      method: :bootstrap,
      iterations: iterations,
      bootstrap_distribution: %{
        mean: Stats.mean(bootstrap_stats),
        sd: Stats.stdev(bootstrap_stats)
      }
    }
  end

  defp calculate_statistic(data, :mean), do: Stats.mean(data)
  defp calculate_statistic(data, :median), do: Stats.median(data)
  defp calculate_statistic(data, :variance), do: Stats.variance(data)
  defp calculate_statistic(data, :stdev), do: Stats.stdev(data)

  defp calculate_statistic(data, fun) when is_function(fun, 1) do
    fun.(data)
  end

  defp resample(data) do
    n = length(data)

    1..n
    |> Enum.map(fn _ -> Enum.random(data) end)
  end

  # Chi-squared quantile approximation
  defp chi_squared_quantile(df, p) do
    # Wilson-Hilferty approximation
    z = Distributions.normal_quantile(p)
    df * :math.pow(1 - 2 / (9 * df) + z * :math.sqrt(2 / (9 * df)), 3)
  end
end
