import Foundation
import VapulaCore

extension Statistics {
  /// Bilateral one-sample Student t. The mean CI is for the population mean;
  /// difference_ci_* is for that mean minus the stated reference mean.
  /// Inputs must already have an explicit missing-value policy applied.
  public static func oneSampleT(
    _ sample: [Double], mean referenceMean: Double = 0, alpha: Double = 0.05
  ) throws -> [String: Double] {
    guard sample.count >= 2, sample.allSatisfy(\.isFinite), referenceMean.isFinite,
      alpha.isFinite, alpha > 0, alpha < 1
    else {
      throw VapulaError.invalid(
        "One-sample t requires at least two finite observations, a finite reference mean and 0 < alpha < 1."
      )
    }
    let summary = try describe(sample.map(Optional.some))
    guard let variance = summary.variance, variance > 0 else {
      throw VapulaError.invalid("One-sample t is undefined when sample variance is zero.")
    }
    let n = Double(sample.count)
    let sd = sqrt(variance)
    let se = sd / sqrt(n)
    let difference = summary.mean - referenceMean
    let statistic = difference / se
    guard se > 0, se.isFinite, statistic.isFinite else {
      throw VapulaError.invalid("One-sample t overflow or underflow; rescale the observations.")
    }
    let df = n - 1
    let critical = try studentQuantile(1 - alpha / 2, df: df)
    let margin = critical * se
    return try finiteMetrics(
      [
        "n": n, "sample_mean": summary.mean, "reference_mean": referenceMean,
        "sample_sd": sd, "standard_error": se, "mean_difference": difference,
        "t": statistic, "df": df, "p_two_sided": try studentTwoSided(statistic, df: df),
        "ci_lower": summary.mean - margin, "ci_upper": summary.mean + margin,
        "difference_ci_lower": difference - margin, "difference_ci_upper": difference + margin,
        "cohen_d": difference / sd,
      ], method: "One-sample t")
  }

  /// Paired Student t on x-y, with n-1 df and Cohen d_z based on difference SD.
  /// Pairs are positional; the caller must remove incomplete pairs together.
  public static func pairedT(
    _ x: [Double], _ y: [Double], alpha: Double = 0.05
  ) throws -> [String: Double] {
    guard x.count == y.count, x.count >= 2, x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite)
    else {
      throw VapulaError.invalid(
        "Paired t requires equal-length finite arrays with at least two complete pairs.")
    }
    let differences = zip(x, y).map { $0 - $1 }
    guard differences.allSatisfy(\.isFinite) else {
      throw VapulaError.invalid("Paired differences overflowed; rescale the observations.")
    }
    var metrics = try oneSampleT(differences, mean: 0, alpha: alpha)
    metrics.removeValue(forKey: "sample_mean")
    metrics.removeValue(forKey: "reference_mean")
    metrics["n_pairs"] = Double(x.count)
    metrics["mean_x"] = try describe(x.map(Optional.some)).mean
    metrics["mean_y"] = try describe(y.map(Optional.some)).mean
    metrics["difference_sd"] = metrics.removeValue(forKey: "sample_sd")
    metrics["cohen_d_z"] = metrics.removeValue(forKey: "cohen_d")
    return try finiteMetrics(metrics, method: "Paired t")
  }

  /// Classical one-way ANOVA: independent observations, approximately normal
  /// residuals and equal population variances. This is not Welch's ANOVA.
  /// Returns omnibus F and eta squared; it does not perform post-hoc comparisons.
  public static func oneWayANOVA(_ groups: [[Double]]) throws -> [String: Double] {
    guard groups.count >= 2, groups.allSatisfy({ $0.count >= 2 && $0.allSatisfy(\.isFinite) })
    else {
      throw VapulaError.invalid(
        "One-way ANOVA requires at least two finite groups with n ≥ 2 in every group.")
    }
    let summaries = try groups.map { try describe($0.map(Optional.some)) }
    let totalN = summaries.reduce(0.0) { $0 + Double($1.n) }
    let anchor = summaries[0].mean
    let grandMean =
      anchor + summaries.reduce(0.0) {
        $0 + Double($1.n) * ($1.mean - anchor)
      } / totalN
    let betweenSS = summaries.reduce(0.0) {
      let difference = $1.mean - grandMean
      return $0 + Double($1.n) * difference * difference
    }
    var withinSS = 0.0
    for summary in summaries {
      guard let variance = summary.variance else {
        throw VapulaError.invalid("ANOVA has insufficient within-group variance information.")
      }
      withinSS += Double(summary.n - 1) * variance
    }
    guard withinSS > 0, withinSS.isFinite, betweenSS.isFinite, grandMean.isFinite else {
      throw VapulaError.invalid(
        "ANOVA requires positive within-group variation without numerical overflow.")
    }
    let dfBetween = Double(groups.count - 1)
    let dfWithin = totalN - Double(groups.count)
    let meanSquareBetween = betweenSS / dfBetween
    let meanSquareWithin = withinSS / dfWithin
    let statistic = meanSquareBetween / meanSquareWithin
    guard statistic.isFinite, meanSquareWithin > 0 else {
      throw VapulaError.invalid("ANOVA overflow or underflow; rescale the observations.")
    }
    let totalSS = withinSS + betweenSS
    guard totalSS.isFinite, totalSS > 0 else {
      throw VapulaError.invalid("ANOVA total variation overflowed; rescale the observations.")
    }
    let betaArgument = dfWithin / (dfWithin + dfBetween * statistic)
    let p = try regularizedBeta(betaArgument, dfWithin / 2, dfBetween / 2)
    return try finiteMetrics(
      [
        "n": totalN, "groups": Double(groups.count), "grand_mean": grandMean,
        "f": statistic, "df_between": dfBetween, "df_within": dfWithin,
        "ss_between": betweenSS, "ss_within": withinSS,
        "ms_between": meanSquareBetween, "ms_within": meanSquareWithin,
        "p_value": p, "eta_squared": betweenSS / totalSS,
      ], method: "One-way ANOVA")
  }

  /// Bilateral asymptotic Mann-Whitney U, average ranks for ties, tie-corrected
  /// normal variance and 0.5 continuity correction. No exact/permutation p-value.
  /// Rank-biserial sign is positive when A tends to be greater than B.
  public static func mannWhitney(_ a: [Double], _ b: [Double]) throws -> [String: Double] {
    guard a.isEmpty == false, b.isEmpty == false, a.allSatisfy(\.isFinite), b.allSatisfy(\.isFinite)
    else {
      throw VapulaError.invalid("Mann-Whitney requires two nonempty finite groups.")
    }
    let combined = a + b
    let ranked = ranks(combined)
    let na = Double(a.count)
    let nb = Double(b.count)
    let n = na + nb
    let rankSumA = ranked.prefix(a.count).reduce(0, +)
    let ua = rankSumA - na * (na + 1) / 2
    let product = na * nb
    let ub = product - ua
    let sorted = combined.sorted()
    var tieTerm = 0.0
    var tieGroups = 0
    var tiedObservations = 0
    var i = 0
    while i < sorted.count {
      var j = i + 1
      while j < sorted.count, sorted[j] == sorted[i] { j += 1 }
      if j - i > 1 {
        let size = Double(j - i)
        tieTerm += size * size * size - size
        tieGroups += 1
        tiedObservations += j - i
      }
      i = j
    }
    let variance = product / 12 * ((n + 1) - tieTerm / (n * (n - 1)))
    guard variance > 0, variance.isFinite else {
      throw VapulaError.invalid(
        "Mann-Whitney is not informative when all observations are tied or rank variance is zero.")
    }
    let centered = ua - product / 2
    let correctedMagnitude = max(0, abs(centered) - 0.5)
    let zMagnitude = correctedMagnitude / sqrt(variance)
    let z = centered < 0 ? -zMagnitude : zMagnitude
    let p = min(1, max(0, erfc(zMagnitude / sqrt(2))))
    return try finiteMetrics(
      [
        "n_a": na, "n_b": nb, "u_a": ua, "u_b": ub,
        "z_corrected": z, "p_two_sided": p,
        "rank_biserial_a_minus_b": 2 * ua / product - 1,
        "tie_groups": Double(tieGroups), "tied_observations": Double(tiedObservations),
        "continuity_correction": 0.5, "minimum_group_n": min(na, nb),
      ], method: "Mann-Whitney")
  }

  /// Pearson chi-square test of independence, with no Yates correction.
  /// Sparse expected counts are reported as diagnostics; the caller must warn
  /// that the asymptotic chi-square approximation can be unreliable for them.
  public static func chiSquare(_ counts: [[Int]]) throws -> [String: Double] {
    guard counts.count >= 2, let columns = counts.first?.count, columns >= 2,
      counts.allSatisfy({ $0.count == columns && $0.allSatisfy({ $0 >= 0 }) })
    else {
      throw VapulaError.invalid(
        "Chi-square requires a rectangular table of nonnegative counts with at least two rows and columns."
      )
    }
    // Counts beyond Double's exact integer range must not silently lose cells.
    let largestExactInteger = 9_007_199_254_740_991.0
    let rowTotals = counts.map { row in row.reduce(0.0) { $0 + Double($1) } }
    var columnTotals = Array(repeating: 0.0, count: columns)
    for row in counts { for column in 0..<columns { columnTotals[column] += Double(row[column]) } }
    let total = rowTotals.reduce(0, +)
    guard total > 0, total <= largestExactInteger, total.isFinite,
      rowTotals.allSatisfy({ $0 > 0 }), columnTotals.allSatisfy({ $0 > 0 })
    else {
      throw VapulaError.invalid(
        "Chi-square needs positive row/column marginals and an exactly representable total count. Remove empty categories."
      )
    }
    var statistic = 0.0
    var minimumExpected = Double.infinity
    var belowFive = 0
    var belowOne = 0
    for row in counts.indices {
      for column in 0..<columns {
        let expected = rowTotals[row] * columnTotals[column] / total
        let difference = Double(counts[row][column]) - expected
        statistic += difference * difference / expected
        minimumExpected = min(minimumExpected, expected)
        if expected < 5 { belowFive += 1 }
        if expected < 1 { belowOne += 1 }
      }
    }
    let df = Double((counts.count - 1) * (columns - 1))
    guard statistic.isFinite else { throw VapulaError.invalid("Chi-square numerical overflow.") }
    let p = try regularizedGammaUpper(df / 2, statistic / 2)
    let v = sqrt(statistic / (total * Double(min(counts.count - 1, columns - 1))))
    return try finiteMetrics(
      [
        "n": total, "rows": Double(counts.count), "columns": Double(columns),
        "chi_square": statistic, "df": df, "p_value": p,
        "cramers_v": min(1, max(0, v)), "minimum_expected": minimumExpected,
        "expected_below_5": Double(belowFive), "expected_below_1": Double(belowOne),
        "expected_below_5_fraction": Double(belowFive) / Double(counts.count * columns),
        "yates_correction": 0,
      ], method: "Chi-square")
  }

  private static func finiteMetrics(_ metrics: [String: Double], method: String) throws
    -> [String: Double]
  {
    guard metrics.values.allSatisfy(\.isFinite) else {
      throw VapulaError.invalid(
        "\(method) produced an overflowing or undefined value; rescale or review the data.")
    }
    return metrics
  }

  /// Upper regularized incomplete gamma Q(a,x). A converged lower-tail series
  /// is used for x<a+1; otherwise a modified Lentz upper-tail fraction is used.
  /// Both branches fail explicitly if convergence is not reached.
  private static func regularizedGammaUpper(_ a: Double, _ x: Double) throws -> Double {
    guard a > 0, a.isFinite, x >= 0, x.isFinite else {
      throw VapulaError.invalid("Invalid incomplete gamma parameters.")
    }
    if x == 0 { return 1 }
    let logFactor = a * log(x) - x - lgamma(a)
    let tolerance = 2e-14
    if x < a + 1 {
      var term = 1 / a
      var sum = term
      for iteration in 1...10000 {
        term *= x / (a + Double(iteration))
        sum += term
        if abs(term) <= abs(sum) * tolerance {
          let result = 1 - sum * exp(logFactor)
          guard result.isFinite else { throw VapulaError.invalid("Gamma series overflow.") }
          return min(1, max(0, result))
        }
      }
    } else {
      let tiny = 1e-300
      var b = x + 1 - a
      var c = 1 / tiny
      var d = 1 / b
      var fraction = d
      for iteration in 1...10000 {
        let i = Double(iteration)
        let coefficient = -i * (i - a)
        b += 2
        d = coefficient * d + b
        if abs(d) < tiny { d = d < 0 ? -tiny : tiny }
        c = b + coefficient / c
        if abs(c) < tiny { c = c < 0 ? -tiny : tiny }
        d = 1 / d
        let change = d * c
        fraction *= change
        if abs(change - 1) <= tolerance {
          let result = exp(logFactor) * fraction
          guard result.isFinite else { throw VapulaError.invalid("Gamma fraction overflow.") }
          return min(1, max(0, result))
        }
      }
    }
    throw VapulaError.invalid("Incomplete gamma did not converge.")
  }
}
