import Foundation
import VapulaCore

extension DataEngine {
  func predicate(_ rule: QualityRule, version v: DatasetVersion, connection c: Connection) throws
    -> String
  {
    switch rule {
    case .missing(let name): return "\(try column(name,in:v)) IS NULL"
    case .blank(let name):
      let n = try column(name, in: v)
      return "\(n) IS NOT NULL AND trim(CAST(\(n) AS VARCHAR), \(try SQL.literal(" \t\r\n")))=''"
    case .nonFinite(let name):
      let n = try column(name, in: v)
      return "\(n) IS NOT NULL AND NOT isfinite(TRY_CAST(\(n) AS DOUBLE))"
    case .range(let name, let lower, let upper):
      guard lower.isFinite, upper.isFinite, lower <= upper else {
        throw VapulaError.invalid("Invalid range.")
      }
      let n = try column(name, in: v)
      return
        "isfinite(TRY_CAST(\(n) AS DOUBLE)) AND (TRY_CAST(\(n) AS DOUBLE)<\(lower) OR TRY_CAST(\(n) AS DOUBLE)>\(upper))"
    case .outlier(let name):
      let n = try column(name, in: v)
      let f = "TRY_CAST(\(n) AS DOUBLE)"
      let r = try c.read(
        "SELECT quantile_cont(\(f),0.25)::DOUBLE,quantile_cont(\(f),0.75)::DOUBLE FROM \(v.tableName) WHERE isfinite(\(f))"
      )
      guard let q1 = r[0].cast(to: Double.self)[0], let q3 = r[1].cast(to: Double.self)[0] else {
        return "false"
      }
      let iqr = q3 - q1
      guard iqr.isFinite, (q1 - 1.5 * iqr).isFinite, (q3 + 1.5 * iqr).isFinite else {
        throw VapulaError.invalid("IQR overflow.")
      }
      return "isfinite(\(f)) AND (\(f)<\(q1-1.5*iqr) OR \(f)>\(q3+1.5*iqr))"
    case .duplicates(let keys):
      try requireRowIdentity(v)
      guard keys.isEmpty == false else { throw VapulaError.invalid("Select duplicate keys.") }
      let fields = try keys.map { try column($0, in: v) }.joined(separator: ",")
      return
        "rowid IN (SELECT rowid FROM (SELECT rowid,count(*) OVER (PARTITION BY \(fields)) AS __vapula_count FROM \(v.tableName)) WHERE __vapula_count>1)"
    }
  }
  public func audit(datasetID: UUID, rules: [QualityRule]) throws -> [QualityFinding] {
    let (c, _, p) = try context()
    let v = try version(datasetID)
    let findings = try rules.map { rule in
      try Task.checkCancellation()
      let condition = try predicate(rule, version: v, connection: c)
      let count = try scalarInt("SELECT count(*)::BIGINT FROM \(v.tableName) WHERE \(condition)", c)
      return QualityFinding(datasetID: datasetID, rule: rule, affectedRows: count)
    }
    try Task.checkCancellation()
    var updated = p
    updated.findings.removeAll { $0.datasetID == datasetID }
    updated.findings.append(contentsOf: findings)
    try persist(updated)
    return findings
  }
  public func evidence(_ finding: QualityFinding) throws -> DataPage {
    let (c, _, _) = try context()
    let v = try version(finding.datasetID)
    let condition = try predicate(finding.rule, version: v, connection: c)
    let projection = try v.columns.map { "CAST(\(try column($0.name,in:v)) AS VARCHAR)" }.joined(
      separator: ",")
    let result = try c.read(
      "SELECT \(projection) FROM \(v.tableName) WHERE \(condition) LIMIT 100")
    return DataPage(rows: Self.rows(result, offset: 0), matchingRows: finding.affectedRows)
  }
  public func numericValues(datasetID: UUID, column name: String, limit: Int = 200_000) throws
    -> [Double?]
  {
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let n = try column(name, in: v)
    guard v.rowCount <= limit else {
      throw VapulaError.invalid(
        "This analysis is limited to \(limit) rows. Filter a version first. Descriptive profiles run over the full dataset."
      )
    }
    let r = try c.read("SELECT TRY_CAST(\(n) AS DOUBLE) FROM \(v.tableName)")
    return (0..<r.rowCount).map { r[0].cast(to: Double.self)[$0] }
  }
}
