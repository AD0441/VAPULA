import Foundation
import VapulaCore
import VapulaStatistics

public struct ChartPoint: Sendable, Identifiable, Equatable {
  public var id: Int
  public var x: Double
  public var y: Double
  public init(id: Int, x: Double, y: Double) {
    self.id = id
    self.x = x
    self.y = y
  }
}
public struct Frequency: Sendable, Identifiable, Equatable {
  public var id: String { label }
  public var label: String
  public var count: Int
}
extension DataEngine {
  public func analyze(datasetID: UUID, specification s: AnalysisSpecification) throws
    -> AnalysisResult
  {
    try Task.checkCancellation()
    let (c, _, p) = try context()
    let v = try version(datasetID)
    guard s.alpha > 0, s.alpha < 1, s.alpha.isFinite else {
      throw VapulaError.invalid("Alpha must be finite and between zero and one.")
    }
    _ = try column(s.x, in: v)
    var metrics: [String: Double] = [:]
    var n = 0
    var procedure = ""
    var warnings = [
      "Association does not imply causation. Measurement scale is unspecified; verify its suitability."
    ]
    switch s.method {
    case .descriptive:
      guard let col = v.columns.first(where: { $0.name == s.x }), col.isNumeric else {
        throw VapulaError.invalid(
          "Choose a numeric variable. Categorical frequencies are available in Visualization.")
      }
      let profile = try profile(datasetID: datasetID).first { $0.column.name == s.x }
      guard let profile, profile.valid > 0 else {
        throw VapulaError.invalid("No finite observations.")
      }
      n = profile.valid
      metrics = ["n": Double(n), "missing_or_nonfinite": Double(profile.missing)]
      metrics["mean"] = profile.mean
      metrics["median"] = profile.median
      metrics["sample_sd"] = profile.sd
      if let sd = profile.sd { metrics["sample_variance"] = sd * sd }
      metrics["q1"] = profile.q1
      metrics["q3"] = profile.q3
      if let q1 = profile.q1, let q3 = profile.q3 { metrics["iqr"] = q3 - q1 }
      if let lo = profile.minimum.flatMap(Double.init),
        let hi = profile.maximum.flatMap(Double.init)
      {
        metrics["minimum"] = lo
        metrics["maximum"] = hi
        metrics["range"] = hi - lo
      }
      procedure =
        "All finite observations; missing/non-finite excluded. Sample variance uses n−1. Quantiles: Hyndman–Fan type 7."
      if n < 2 { warnings.append("Sample variance/SD require n ≥ 2 and are omitted.") }
    case .pearson, .spearman, .regression, .pairedT:
      _ = try column(s.y, in: v)
      guard v.rowCount <= 200_000 else {
        throw VapulaError.invalid(
          "Paired analyses are limited to 200,000 rows. Filter first; no silent sampling.")
      }
      let a = try numericValues(datasetID: datasetID, column: s.x)
      let b = try numericValues(datasetID: datasetID, column: s.y)
      let pairs = zip(a, b).compactMap { x, y -> (Double, Double)? in
        guard let x, let y, x.isFinite, y.isFinite else { return nil }
        return (x, y)
      }
      n = pairs.count
      let x = pairs.map(\.0)
      let y = pairs.map(\.1)
      switch s.method {
      case .pearson:
        metrics["pearson_r"] = try Statistics.pearson(x, y)
        procedure = "Pairwise finite complete cases. Pearson correlation. No p-value is reported."
      case .pairedT:
        metrics = try Statistics.pairedT(x, y, alpha: s.alpha)
        procedure =
          "Paired t test; H0: mean(X−Y)=0; two-sided Student t, complete finite pairs, alpha=\(s.alpha), CI level=\(1-s.alpha). Check normality of differences and independence between units."
      case .spearman:
        metrics["spearman_rho"] = try Statistics.spearman(x, y)
        procedure =
          "Pairwise finite complete cases. Pearson correlation of average ranks for ties. No p-value is reported."
      default:
        metrics = try Statistics.regression(x, y)
        procedure =
          "Centered covariance OLS for one predictor; no matrix inversion. Complete finite pairs. Residual scale uses n−2."
      }
      if s.method != .pairedT {
        warnings.append(
          "Check independence, linearity (Pearson/OLS) or monotonicity (Spearman), outliers and residual assumptions."
        )
      }
    case .oneSampleT:
      let values = try numericValues(datasetID: datasetID, column: s.x).compactMap { $0 }.filter(
        \.isFinite)
      n = values.count
      metrics = try Statistics.oneSampleT(values, mean: s.hypothesizedMean ?? 0, alpha: s.alpha)
      procedure =
        "One-sample t; H0: μ=μ0 (\(s.hypothesizedMean ?? 0)); two-sided Student t, finite observations, alpha=\(s.alpha), CI level=\(1-s.alpha). Requires independent observations and approximate normality of the sample mean."
    case .welch, .mannWhitney:
      guard s.groupA != s.groupB, s.groupA.isEmpty == false, s.groupB.isEmpty == false else {
        throw VapulaError.invalid("Choose two different nonempty group labels.")
      }
      guard v.rowCount <= 200_000 else {
        throw VapulaError.invalid("Welch is limited to 200,000 rows. Filter first.")
      }
      let g = try column(s.group, in: v)
      let x = try column(s.x, in: v)
      let statement = try PreparedStatement(
        connection: c,
        query:
          "SELECT TRY_CAST(\(x) AS DOUBLE),CAST(\(g) AS VARCHAR) FROM \(v.tableName) WHERE CAST(\(g) AS VARCHAR) IN (?,?)"
      )
      try statement.bind(s.groupA, at: 1)
      try statement.bind(s.groupB, at: 2)
      let r = try statement.read()
      var a: [Double] = []
      var b: [Double] = []
      for i in 0..<r.rowCount {
        if let value = r[0].cast(to: Double.self)[i], value.isFinite {
          if r[1].cast(to: String.self)[i] == s.groupA { a.append(value) } else { b.append(value) }
        }
      }
      metrics =
        s.method == .welch
        ? try Statistics.welch(a, b, alpha: s.alpha) : try Statistics.mannWhitney(a, b)
      n = a.count + b.count
      procedure =
        "H0: μA = μB; H1: μA ≠ μB. Independent samples, Welch–Satterthwaite df, two-sided Student t; alpha=\(s.alpha). CI level=\(1-s.alpha). Cohen d_av=(meanA−meanB)/sqrt((varianceA+varianceB)/2). Finite values from exactly the selected groups; other groups and missing values excluded."
      if s.method == .mannWhitney {
        procedure =
          "Mann–Whitney U; H0: equal independent distributions; two-sided asymptotic normal approximation, average ranks, tie variance and continuity correction. Finite values from the selected groups only; alpha=\(s.alpha)."
        warnings.append(
          "This is not automatically a test of medians. Small samples and many ties limit the asymptotic approximation."
        )
      }
      if s.method == .welch {
        warnings.append(
          "Requires independent observations and approximate normality of sample means. A small p-value does not establish a meaningful effect or causality."
        )
      }
    case .anova:
      let groups = try groupedValues(version: v, column: s.x, group: s.group, connection: c)
      metrics = try Statistics.oneWayANOVA(groups.values.map { $0 })
      n = groups.values.reduce(0) { $0 + $1.count }
      procedure =
        "Classical one-way ANOVA; H0: all group means are equal. Finite response and non-null group values only, alpha=\(s.alpha)."
      warnings.append(
        "Requires independent observations, comparable group variances and approximately normal residuals. This omnibus test does not identify differing pairs; no post-hoc comparison is implied."
      )
    case .chiSquare:
      let counts = try contingency(version: v, x: s.x, y: s.y, connection: c)
      metrics = try Statistics.chiSquare(counts)
      n = counts.reduce(0) { $0 + $1.reduce(0, +) }
      procedure =
        "Pearson chi-square test of independence, without Yates correction; non-null categorical pairs, alpha=\(s.alpha)."
      warnings.append(
        "Expected counts below 5 or any below 1 may make the asymptotic p-value unreliable; inspect the expected-count metrics. No Fisher exact test is claimed."
      )
    }
    var ancestor: DatasetVersion? = v
    var visited = Set<UUID>()
    while let current = ancestor, visited.insert(current.id).inserted {
      if case .missing(_, let action, _) = current.operation,
        action != .dropRows, action != .dropColumns {
        warnings.append("Esta versión contiene valores completados por imputación. El procedimiento puede modificar la dispersión y las asociaciones; los intervalos y p-valores no incorporan la incertidumbre de esa imputación.")
        break
      }
      ancestor = current.parentID.flatMap { parent in p.datasets.first { $0.id == parent } }
    }
    guard metrics.values.allSatisfy(\.isFinite) else {
      throw VapulaError.invalid("A result overflowed; rescale the variables.")
    }
    let result = AnalysisResult(
      datasetID: datasetID, specification: s, validCount: n, excludedCount: v.rowCount - n,
      metrics: metrics, warnings: warnings, procedure: procedure)
    try Task.checkCancellation()
    var updated = p
    updated.results.append(result)
    try persist(updated)
    return result
  }
  public func frequencies(datasetID: UUID, column name: String) throws -> [Frequency] {
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let n = try column(name, in: v)
    let r = try c.read(
      "SELECT \(n) IS NULL,CAST(\(n) AS VARCHAR),count(*)::BIGINT FROM \(v.tableName) GROUP BY \(n) ORDER BY count(*) DESC,CAST(\(n) AS VARCHAR) LIMIT 30"
    )
    return (0..<r.rowCount).map { i in
      Frequency(
        label: r[0].cast(to: Bool.self)[i] == true
          ? "∅ (NULL)" : (r[1].cast(to: String.self)[i] ?? ""),
        count: r[2].cast(to: Int.self)[i] ?? 0)
    }
  }
  public func scatter(datasetID: UUID, x: String, y: String) throws -> [ChartPoint] {
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let a = try column(x, in: v)
    let b = try column(y, in: v)
    let r = try c.read(
      "SELECT TRY_CAST(\(a) AS DOUBLE),TRY_CAST(\(b) AS DOUBLE) FROM \(v.tableName) WHERE isfinite(TRY_CAST(\(a) AS DOUBLE)) AND isfinite(TRY_CAST(\(b) AS DOUBLE)) LIMIT 2000"
    )
    return (0..<r.rowCount).compactMap { i in
      guard let x = r[0].cast(to: Double.self)[i], let y = r[1].cast(to: Double.self)[i] else {
        return nil
      }
      return ChartPoint(id: Int(i), x: x, y: y)
    }
  }
  public func histogram(datasetID: UUID, column name: String, bins: Int = 20) throws -> [ChartPoint]
  {
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let a = try column(name, in: v)
    guard (5...100).contains(bins) else {
      throw VapulaError.invalid("Histogram bins must be between 5 and 100.")
    }
    let expr = "TRY_CAST(\(a) AS DOUBLE)"
    let r = try c.read(
      "WITH finite AS (SELECT \(expr) AS x FROM \(v.tableName) WHERE isfinite(\(expr))), bounds AS (SELECT min(x) lo,max(x) hi FROM finite), bins AS (SELECT CASE WHEN hi=lo THEN 0 ELSE least(\(bins-1),floor((x-lo)/((hi-lo)/\(bins)))) END b,lo,hi FROM finite,bounds) SELECT (lo+CASE WHEN hi=lo THEN 0 ELSE (b+0.5)*(hi-lo)/\(bins) END)::DOUBLE,count(*)::DOUBLE FROM bins GROUP BY b,lo,hi ORDER BY b"
    )
    return (0..<r.rowCount).compactMap { i in
      guard let x = r[0].cast(to: Double.self)[i], let y = r[1].cast(to: Double.self)[i] else {
        return nil
      }
      return ChartPoint(id: Int(i), x: x, y: y)
    }
  }
}
public struct BoxSummary: Sendable, Equatable {
  public var q1: Double
  public var median: Double
  public var q3: Double
  public var lower: Double
  public var upper: Double
  public var outliers: Int
}
extension DataEngine {
  public func boxplot(datasetID: UUID, column name: String) throws -> BoxSummary? {
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let n = try column(name, in: v)
    let r = try c.read(
      "WITH f AS (SELECT TRY_CAST(\(n) AS DOUBLE) x FROM \(v.tableName) WHERE isfinite(TRY_CAST(\(n) AS DOUBLE))), q AS (SELECT quantile_cont(x,0.25)::DOUBLE a,median(x)::DOUBLE m,quantile_cont(x,0.75)::DOUBLE b FROM f) SELECT a,m,b,min(x) FILTER(WHERE x>=a-1.5*(b-a))::DOUBLE,max(x) FILTER(WHERE x<=b+1.5*(b-a))::DOUBLE,count(*) FILTER(WHERE x<a-1.5*(b-a) OR x>b+1.5*(b-a))::BIGINT FROM f,q GROUP BY a,m,b"
    )
    guard r.rowCount > 0, let a = r[0].cast(to: Double.self)[0],
      let m = r[1].cast(to: Double.self)[0], let b = r[2].cast(to: Double.self)[0],
      let lo = r[3].cast(to: Double.self)[0], let hi = r[4].cast(to: Double.self)[0]
    else { return nil }
    return BoxSummary(
      q1: a, median: m, q3: b, lower: lo, upper: hi, outliers: r[5].cast(to: Int.self)[0] ?? 0)
  }
}
