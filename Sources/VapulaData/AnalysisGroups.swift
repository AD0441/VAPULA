import Foundation
import VapulaCore

extension DataEngine {
  func groupedValues(
    version v: DatasetVersion, column name: String, group: String, connection c: Connection
  ) throws -> [String: [Double]] {
    guard v.rowCount <= 200_000 else {
      throw VapulaError.invalid("Group tests are limited to 200,000 source rows. Filter first.")
    }
    let x = try column(name, in: v)
    let g = try column(group, in: v)
    let result = try c.read(
      "SELECT CAST(\(g) AS VARCHAR),TRY_CAST(\(x) AS DOUBLE) FROM \(v.tableName) WHERE \(g) IS NOT NULL AND isfinite(TRY_CAST(\(x) AS DOUBLE))"
    )
    var groups: [String: [Double]] = [:]
    for i in 0..<result.rowCount {
      if let label = result[0].cast(to: String.self)[i],
        let value = result[1].cast(to: Double.self)[i]
      {
        groups[label, default: []].append(value)
      }
      guard groups.count <= 100 else {
        throw VapulaError.invalid(
          "ANOVA supports at most 100 groups; use a categorical grouping variable.")
      }
    }
    return groups
  }
  func contingency(version v: DatasetVersion, x: String, y: String, connection c: Connection) throws
    -> [[Int]]
  {
    let a = try column(x, in: v)
    let b = try column(y, in: v)
    let r = try c.read(
      "SELECT CAST(\(a) AS VARCHAR),CAST(\(b) AS VARCHAR),count(*)::BIGINT FROM \(v.tableName) WHERE \(a) IS NOT NULL AND \(b) IS NOT NULL GROUP BY \(a),\(b) LIMIT 2501"
    )
    guard r.rowCount <= 2500 else {
      throw VapulaError.invalid(
        "The contingency table is too large; use categorical variables with at most 50 levels each."
      )
    }
    var cells: [(String, String, Int)] = []
    for i in 0..<r.rowCount {
      if let a = r[0].cast(to: String.self)[i], let b = r[1].cast(to: String.self)[i],
        let n = r[2].cast(to: Int.self)[i]
      {
        cells.append((a, b, n))
      }
    }
    let rows = Array(Set(cells.map(\.0))).sorted()
    let columns = Array(Set(cells.map(\.1))).sorted()
    guard (2...50).contains(rows.count), (2...50).contains(columns.count) else {
      throw VapulaError.invalid("Chi-square needs 2–50 nonempty categories in each variable.")
    }
    let rowMap = Dictionary(uniqueKeysWithValues: rows.enumerated().map { ($0.element, $0.offset) })
    let colMap = Dictionary(
      uniqueKeysWithValues: columns.enumerated().map { ($0.element, $0.offset) })
    var matrix = Array(repeating: Array(repeating: 0, count: columns.count), count: rows.count)
    for (a, b, n) in cells { if let i = rowMap[a], let j = colMap[b] { matrix[i][j] = n } }
    return matrix
  }
  public func saveChartConfiguration(datasetID: UUID, configuration: ChartConfiguration) throws {
    _ = try version(datasetID)
    var p = try snapshot()
    var configurations = p.chartConfigurations ?? [:]
    configurations[datasetID.uuidString] = configuration.normalized()
    p.chartConfigurations = configurations
    try persist(p)
  }
}
extension DataEngine {
  public func groupLabels(datasetID: UUID, column name: String) throws -> [String] {
    try Task.checkCancellation()
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let g = try column(name, in: v)
    let r = try c.read(
      "SELECT DISTINCT CAST(\(g) AS VARCHAR) FROM \(v.tableName) WHERE \(g) IS NOT NULL ORDER BY 1 LIMIT 101"
    )
    guard r.rowCount <= 100 else {
      throw VapulaError.invalid("The group column has more than 100 categories.")
    }
    try Task.checkCancellation()
    return (0..<r.rowCount).compactMap { r[0].cast(to: String.self)[$0] }
  }
}
