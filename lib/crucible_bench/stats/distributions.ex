defmodule CrucibleBench.Stats.Distributions do
  @moduledoc """
  Probability distributions and statistical functions.

  Provides CDF and quantile functions for common distributions.
  """

  @doc """
  Standard normal cumulative distribution function (CDF).

  Uses error function approximation for standard normal.
  """
  def normal_cdf(z, mu \\ 0, sigma \\ 1) do
    z_standard = (z - mu) / sigma
    0.5 * (1 + erf(z_standard / :math.sqrt(2)))
  end

  @doc """
  Standard normal quantile (inverse CDF).

  Approximation of the inverse normal CDF.
  """
  def normal_quantile(p) when p > 0 and p < 1 do
    # Rational approximation for inverse normal CDF
    # Beasley-Springer-Moro algorithm
    a = [
      2.50662823884,
      -18.61500062529,
      41.39119773534,
      -25.44106049637
    ]

    b = [
      -8.47351093090,
      23.08336743743,
      -21.06224101826,
      3.13082909833
    ]

    c = [
      0.3374754822726147,
      0.9761690190917186,
      0.1607979714918209,
      0.0276438810333863,
      0.0038405729373609,
      0.0003951896511919,
      0.0000321767881768,
      0.0000002888167364,
      0.0000003960315187
    ]

    y = p - 0.5

    if abs(y) < 0.42 do
      r = y * y

      numerator =
        Enum.reduce(Enum.with_index(a), 0, fn {coef, i}, acc ->
          acc + coef * :math.pow(r, i)
        end)

      denominator =
        1 +
          Enum.reduce(Enum.with_index(b), 0, fn {coef, i}, acc ->
            acc + coef * :math.pow(r, i + 1)
          end)

      y * numerator / denominator
    else
      r = if y > 0, do: p, else: 1 - p
      r = :math.log(-:math.log(r))

      Enum.reduce(Enum.with_index(c), 0, fn {coef, i}, acc ->
        acc + coef * :math.pow(r, i)
      end)
      |> then(fn result -> if y < 0, do: -result, else: result end)
    end
  end

  @doc """
  Student's t-distribution CDF.

  Approximation using beta function relationship.
  """
  def t_cdf(t, df) do
    x = df / (df + t * t)
    beta_cdf = incomplete_beta(df / 2, 0.5, x)

    if t >= 0 do
      1 - 0.5 * beta_cdf
    else
      0.5 * beta_cdf
    end
  end

  @doc """
  Student's t-distribution quantile.

  Approximation for t-distribution inverse CDF.
  """
  def t_quantile(df, p) when p > 0 and p < 1 do
    # For large df, approximate with normal distribution
    if df > 30 do
      normal_quantile(p)
    else
      # Hill's algorithm for t-distribution quantile
      a = 1 / (df - 0.5)
      b = 48 / (a * a)
      c = ((20700 * a / b - 98) * a - 16) * a + 96.36
      d = ((94.5 / (b + c) - 3) / b + 1) * :math.sqrt(a * :math.pi() / 2) * df
      y = :math.pow(d * p, 2 / df)

      y =
        if y > 0.05 + a do
          x = normal_quantile(p)
          y_temp = x * x

          c =
            if df < 5 do
              c + 0.3 * (df - 4.5) * (x + 0.6)
            else
              c
            end

          c =
            (((0.05 * d * x - 5) * x - 7) * x - 2) * x + b +
              c

          y_temp =
            (((((0.4 * y_temp + 6.3) * y_temp + 36) * y_temp + 94.5) / c - y_temp - 3) / b + 1) *
              x

          y_temp = a * y_temp * y_temp

          if y_temp > 0.002 do
            :math.exp(y_temp) - 1
          else
            0.5 * y_temp * y_temp + y_temp
          end
        else
          ((1 / (((df + 6) / (df * y) - 0.089 * d - 0.822) * (df + 2) * 3) + 0.5 / (df + 4)) * y -
             1) * (df + 1) / (df + 2) + 1 / y
        end

      :math.sqrt(df * y)
      |> then(fn result -> if p < 0.5, do: -result, else: result end)
    end
  end

  @doc """
  F-distribution CDF.

  Approximation using beta function relationship.
  """
  def f_cdf(f, df1, df2) do
    x = df1 * f / (df1 * f + df2)
    incomplete_beta(df1 / 2, df2 / 2, x)
  end

  @doc """
  Chi-squared distribution CDF.

  Uses gamma function relationship.
  """
  def chi_squared_cdf(x, df) do
    lower_gamma(df / 2, x / 2) / gamma(df / 2)
  end

  # Error function approximation
  defp erf(x) do
    # Abramowitz and Stegun approximation
    a1 = 0.254829592
    a2 = -0.284496736
    a3 = 1.421413741
    a4 = -1.453152027
    a5 = 1.061405429
    p = 0.3275911

    sign = if x < 0, do: -1, else: 1
    x = abs(x)

    t = 1.0 / (1.0 + p * x)
    y = 1.0 - ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t * :math.exp(-x * x)

    sign * y
  end

  # Incomplete beta function (simplified approximation)
  defp incomplete_beta(_a, _b, x) when x == 0, do: 0.0
  defp incomplete_beta(_a, _b, x) when x == 1, do: 1.0

  defp incomplete_beta(a, b, x) do
    # Continued fraction approximation
    beta_ab = beta_function(a, b)
    beta_inc = incomplete_beta_continued_fraction(a, b, x)
    beta_inc / beta_ab
  end

  defp beta_function(a, b) do
    :math.exp(log_gamma(a) + log_gamma(b) - log_gamma(a + b))
  end

  defp incomplete_beta_continued_fraction(a, b, x, max_iter \\ 100) do
    front = :math.pow(x, a) * :math.pow(1 - x, b) / a

    c = 1.0
    d = 1.0 - (a + b) * x / (a + 1)

    d = if abs(d) < 1.0e-30, do: 1.0e-30, else: d
    d = 1.0 / d
    f = d

    Enum.reduce_while(1..max_iter, {f, c, d}, fn m, {f, c, d} ->
      m = m * 1.0
      m2 = m * 2

      aa = m * (b - m) * x / ((a + m2 - 1) * (a + m2))

      d = 1.0 + aa * d
      d = if abs(d) < 1.0e-30, do: 1.0e-30, else: d
      c = 1.0 + aa / c
      c = if abs(c) < 1.0e-30, do: 1.0e-30, else: c
      d = 1.0 / d
      f = f * d * c

      aa = -(a + m) * (a + b + m) * x / ((a + m2) * (a + m2 + 1))

      d = 1.0 + aa * d
      d = if abs(d) < 1.0e-30, do: 1.0e-30, else: d
      c = 1.0 + aa / c
      c = if abs(c) < 1.0e-30, do: 1.0e-30, else: c
      d = 1.0 / d
      delta = d * c
      f = f * delta

      if abs(delta - 1.0) < 1.0e-10 do
        {:halt, {f, c, d}}
      else
        {:cont, {f, c, d}}
      end
    end)
    |> elem(0)
    |> then(&(front * &1))
  end

  # Gamma function approximation
  defp gamma(x) do
    :math.exp(log_gamma(x))
  end

  # Log-gamma function (Lanczos approximation)
  defp log_gamma(x) do
    g = 7

    coef = [
      0.99999999999980993,
      676.5203681218851,
      -1259.1392167224028,
      771.32342877765313,
      -176.61502916214059,
      12.507343278686905,
      -0.13857109526572012,
      9.9843695780195716e-6,
      1.5056327351493116e-7
    ]

    if x < 0.5 do
      :math.log(:math.pi()) - :math.log(:math.sin(:math.pi() * x)) - log_gamma(1 - x)
    else
      x = x - 1
      base = x + g + 0.5

      series =
        Enum.reduce(1..8, Enum.at(coef, 0), fn i, acc ->
          acc + Enum.at(coef, i) / (x + i)
        end)

      :math.log(:math.sqrt(2 * :math.pi())) + :math.log(series) - base +
        :math.log(base) * (x + 0.5)
    end
  end

  # Lower incomplete gamma function
  defp lower_gamma(a, x) do
    gamma(a) * incomplete_gamma_p(a, x)
  end

  defp incomplete_gamma_p(a, x, max_iter \\ 100) do
    if x < a + 1 do
      # Use series representation
      ap = a
      del = 1.0 / a
      sum = del

      Enum.reduce_while(1..max_iter, {sum, del, ap}, fn _n, {sum, del, ap} ->
        ap = ap + 1
        del = del * x / ap
        sum = sum + del

        if abs(del) < abs(sum) * 1.0e-10 do
          {:halt, sum * :math.exp(-x + a * :math.log(x) - log_gamma(a))}
        else
          {:cont, {sum, del, ap}}
        end
      end)
      |> then(fn
        {sum, _, _} -> sum * :math.exp(-x + a * :math.log(x) - log_gamma(a))
        result -> result
      end)
    else
      # Use continued fraction
      1.0 - incomplete_gamma_q_cf(a, x)
    end
  end

  defp incomplete_gamma_q_cf(a, x, max_iter \\ 100) do
    b = x + 1 - a
    c = 1.0 / 1.0e-30
    d = 1.0 / b
    h = d

    Enum.reduce_while(1..max_iter, {h, d, c, b}, fn i, {h, d, c, b} ->
      an = -i * (i - a)
      b = b + 2
      d = an * d + b
      d = if abs(d) < 1.0e-30, do: 1.0e-30, else: d
      c = b + an / c
      c = if abs(c) < 1.0e-30, do: 1.0e-30, else: c
      d = 1.0 / d
      delta = d * c
      h = h * delta

      if abs(delta - 1.0) < 1.0e-10 do
        {:halt, h * :math.exp(-x + a * :math.log(x) - log_gamma(a))}
      else
        {:cont, {h, d, c, b}}
      end
    end)
    |> then(fn
      {h, _, _, _} -> h * :math.exp(-x + a * :math.log(x) - log_gamma(a))
      result -> result
    end)
  end
end
