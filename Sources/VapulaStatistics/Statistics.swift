import Foundation
import VapulaCore

public struct DescriptiveSummary: Sendable {
  public let n: Int
  public let missing: Int
  public let mean: Double
  public let median: Double
  public let minimum: Double
  public let maximum: Double
  public let variance: Double?
  public let q1: Double
  public let q3: Double
  public var metrics: [String: Double] {
    var m = [
      "n": Double(n), "missing": Double(missing), "mean": mean, "median": median,
      "minimum": minimum, "maximum": maximum, "range": maximum - minimum, "q1": q1, "q3": q3,
      "iqr": q3 - q1,
    ]
    if let variance {
      m["sample_variance"] = variance
      m["sample_sd"] = sqrt(variance)
    }
    return m
  }
}
public enum Statistics {
  public static func describe(_ input: [Double?]) throws -> DescriptiveSummary {
    let x = input.compactMap { $0 }.filter(\.isFinite).sorted()
    guard let first = x.first, let last = x.last else {
      throw VapulaError.invalid("No finite observations.")
    }
    var mean = 0.0
    var m2 = 0.0
    for (i, value) in x.enumerated() {
      let d = value - mean
      mean += d / Double(i + 1)
      m2 += d * (value - mean)
    }
    guard mean.isFinite, m2.isFinite else {
      throw VapulaError.invalid("Numerical overflow: rescale the variable.")
    }
    return DescriptiveSummary(
      n: x.count, missing: input.count - x.count, mean: mean, median: quantile(x, 0.5),
      minimum: first, maximum: last, variance: x.count > 1 ? max(0, m2 / Double(x.count - 1)) : nil,
      q1: quantile(x, 0.25), q3: quantile(x, 0.75))
  }
  /// Hyndman–Fan type 7, matching R default and NumPy method='linear'. Input is sorted and nonempty.
  public static func quantile(_ sorted: [Double], _ p: Double) -> Double {
    precondition(sorted.isEmpty == false && (0...1).contains(p))
    let h = Double(sorted.count - 1) * p
    let i = Int(h)
    let f = h - Double(i)
    return sorted[i] * (1 - f) + sorted[min(i + 1, sorted.count - 1)] * f
  }
  public static func ranks(_ x: [Double]) -> [Double] {
    let indices = x.indices.sorted { x[$0] < x[$1] }
    var result = Array(repeating: 0.0, count: x.count)
    var i = 0
    while i < indices.count {
      var j = i + 1
      while j < indices.count && x[indices[j]] == x[indices[i]] { j += 1 }
      let rank = Double(i + 1 + j) / 2
      for k in i..<j { result[indices[k]] = rank }
      i = j
    }
    return result
  }
  public static func pearson(_ x: [Double], _ y: [Double]) throws -> Double {
    let moments = try centered(x, y)
    let r = moments.xy / sqrt(moments.xx) / sqrt(moments.yy)
    guard r.isFinite else {
      throw VapulaError.invalid("Correlation is not finite; rescale the variables.")
    }
    return min(1, max(-1, r))
  }
  public static func spearman(_ x: [Double], _ y: [Double]) throws -> Double {
    try pearson(ranks(x), ranks(y))
  }
  public static func regression(_ x: [Double], _ y: [Double]) throws -> [String: Double] {
    guard x.count >= 3 else {
      throw VapulaError.invalid("Regression requires at least three complete pairs.")
    }
    let m = try centered(x, y)
    let slope = m.xy / m.xx
    let intercept = m.my - slope * m.mx
    let residuals = zip(x, y).map { $1 - (intercept + slope * $0) }
    let sse = residuals.reduce(0) { $0 + $1 * $1 }
    let r = try pearson(x, y)
    let result = [
      "slope": slope, "intercept": intercept, "r_squared": r * r, "residual_ss": sse,
      "residual_sd": sqrt(sse / Double(x.count - 2)),
      "slope_se": sqrt(sse / Double(x.count - 2) / m.xx),
    ]
    guard result.values.allSatisfy(\.isFinite) else {
      throw VapulaError.invalid("Regression overflow: rescale the variables.")
    }
    return result
  }
  public static func welch(_ a: [Double], _ b: [Double], alpha: Double = 0.05) throws -> [String:
    Double]
  {
    guard a.count >= 2, b.count >= 2, a.allSatisfy(\.isFinite), b.allSatisfy(\.isFinite), alpha > 0,
      alpha < 1
    else {
      throw VapulaError.invalid("Welch requires two finite groups with n ≥ 2 and 0 < alpha < 1.")
    }
    let sa = try describe(a.map(Optional.some))
    let sb = try describe(b.map(Optional.some))
    guard let va = sa.variance, let vb = sb.variance else {
      throw VapulaError.invalid("Insufficient variance information.")
    }
    let u = va / Double(a.count)
    let v = vb / Double(b.count)
    let se = sqrt(u + v)
    guard se > 0, se.isFinite else {
      throw VapulaError.invalid("Both groups have zero variance or numerical overflow.")
    }
    let df = (u + v) * (u + v) / (u * u / Double(a.count - 1) + v * v / Double(b.count - 1))
    let difference = sa.mean - sb.mean
    let t = difference / se
    let p = try studentTwoSided(t, df: df)
    let critical = try studentQuantile(1 - alpha / 2, df: df)
    let values = [
      "n_a": Double(a.count), "n_b": Double(b.count), "mean_a": sa.mean, "mean_b": sb.mean,
      "difference_a_minus_b": difference, "t": t, "df": df, "p_two_sided": p,
      "ci_lower": difference - critical * se, "ci_upper": difference + critical * se,
      "cohen_d_av": difference / sqrt((va + vb) / 2),
    ]
    guard values.values.allSatisfy(\.isFinite) else {
      throw VapulaError.invalid("Welch numerical overflow; rescale data.")
    }
    return values
  }
  private static func centered(_ x: [Double], _ y: [Double]) throws -> (
    mx: Double, my: Double, xx: Double, yy: Double, xy: Double
  ) {
    guard x.count == y.count, x.count >= 2, x.allSatisfy(\.isFinite), y.allSatisfy(\.isFinite)
    else { throw VapulaError.invalid("At least two finite, paired observations are required.") }
    var mx = 0.0
    var my = 0.0
    var xx = 0.0
    var yy = 0.0
    var xy = 0.0
    for i in x.indices {
      let n = Double(i + 1)
      let dx = x[i] - mx
      let dy = y[i] - my
      mx += dx / n
      my += dy / n
      xx += dx * (x[i] - mx)
      yy += dy * (y[i] - my)
      xy += dx * (y[i] - my)
    }
    guard xx > 0, yy > 0, xx.isFinite, yy.isFinite, xy.isFinite else {
      throw VapulaError.invalid(
        "Constant, singular or overflowing variables. Correlation/R² is undefined.")
    }
    return (mx, my, xx, yy, xy)
  }
  public static func studentTwoSided(_ t: Double, df: Double) throws -> Double {
    guard df > 0, df.isFinite, t.isFinite else {
      throw VapulaError.invalid("Invalid Student t parameters.")
    }
    return try regularizedBeta(df / (df + t * t), df / 2, 0.5)
  }
  public static func studentQuantile(_ probability: Double, df: Double) throws -> Double {
    guard probability > 0.5, probability < 1 else {
      throw VapulaError.invalid("Upper-tail quantile probability must be in (0.5,1).")
    }
    let target = 2 * (1 - probability)
    var low = 0.0
    var high = 1.0
    while try studentTwoSided(high, df: df) > target {
      high *= 2
      guard high < 1e15 else {
        throw VapulaError.invalid("Quantile outside supported numeric range.")
      }
    }
    for _ in 0..<160 {
      let mid = (low + high) / 2
      if try studentTwoSided(mid, df: df) > target { low = mid } else { high = mid }
    }
    return (low + high) / 2
  }
  static func regularizedBeta(_ x: Double, _ a: Double, _ b: Double) throws -> Double {
    if x <= 0 { return 0 }
    if x >= 1 { return 1 }
    let factor = exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * log(x) + b * log1p(-x))
    let result: Double
    if x < (a + 1) / (a + b + 2) {
      result = try factor * fraction(x, a, b) / a
    } else {
      result = try 1 - factor * fraction(1 - x, b, a) / b
    }
    guard result.isFinite else { throw VapulaError.invalid("Beta evaluation failed.") }
    return max(0, min(1, result))
  }
  /// Modified Lentz continued fraction; refuses unconverged values instead of returning an approximation silently.
  private static func fraction(_ x: Double, _ a: Double, _ b: Double) throws -> Double {
    let tiny = 1e-300
    var c = 1.0
    var d = 1 - (a + b) * x / (a + 1)
    if abs(d) < tiny { d = tiny }
    d = 1 / d
    var h = d
    for m in 1...10000 {
      let fm = Double(m)
      let m2 = 2 * fm
      var aa = fm * (b - fm) * x / ((a + m2 - 1) * (a + m2))
      d = 1 + aa * d
      if abs(d) < tiny { d = tiny }
      c = 1 + aa / c
      if abs(c) < tiny { c = tiny }
      d = 1 / d
      h *= d * c
      aa = -(a + fm) * (a + b + fm) * x / ((a + m2) * (a + m2 + 1))
      d = 1 + aa * d
      if abs(d) < tiny { d = tiny }
      c = 1 + aa / c
      if abs(c) < tiny { c = tiny }
      d = 1 / d
      let delta = d * c
      h *= delta
      if abs(delta - 1) < 2e-14 { return h }
    }
    throw VapulaError.invalid("Incomplete beta did not converge.")
  }
}
