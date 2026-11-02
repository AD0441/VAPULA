import Foundation
import VapulaCore

extension DataEngine {
  public func castImpact(datasetID: UUID, column name: String, type: PhysicalType) throws -> CastImpact {
    try Task.checkCancellation()
    let (c, _, _) = try context()
    let version = try version(datasetID)
    let nameSQL = try column(name, in: version)
    let predicate = "\(nameSQL) IS NOT NULL AND TRY_CAST(\(nameSQL) AS \(type.rawValue)) IS NULL"
    let losses = try scalarInt("SELECT count(*)::BIGINT FROM \(version.tableName) WHERE \(predicate)", c)
    let existing = try scalarInt("SELECT count(*)::BIGINT FROM \(version.tableName) WHERE \(nameSQL) IS NULL", c)
    let r = try c.read("SELECT CAST(\(nameSQL) AS VARCHAR) FROM \(version.tableName) WHERE \(predicate) LIMIT 5")
    let values = r[0].cast(to: String.self)
    let examples = (0..<r.rowCount).compactMap { values[$0].map { String($0.prefix(180)) } }
    try Task.checkCancellation()
    return CastImpact(approval: CastApproval(datasetID: datasetID, column: name, type: type, newNulls: losses),
      existingNulls: existing, examples: examples)
  }
}
