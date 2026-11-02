import Foundation
import VapulaCore

extension DataEngine {
  public func page(
    datasetID: UUID, offset: Int = 0, limit: Int = 100, search: String = "", sort: String? = nil,
    ascending: Bool = true
  ) throws -> DataPage {
    try Task.checkCancellation()
    let (c, _, _) = try context()
    let v = try version(datasetID)
    guard offset >= 0, (1...500).contains(limit) else {
      throw VapulaError.invalid("Invalid page bounds.")
    }
    let names = try v.columns.map { try SQL.identifier($0.name) }
    let rowReference = v.columns.contains(where: { $0.name.caseInsensitiveCompare("rowid") == .orderedSame }) ? "NULL::BIGINT" : "rowid::BIGINT"
    let whereSQL =
      search.isEmpty
      ? ""
      : " WHERE " + names.map { "contains(CAST(\($0) AS VARCHAR), ?)" }.joined(separator: " OR ")
    let order =
      try sort.map { " ORDER BY \(try column($0,in:v)) \(ascending ? "ASC" : "DESC") NULLS LAST" }
      ?? " ORDER BY rowid"
    let count = try PreparedStatement(
      connection: c, query: "SELECT count(*)::BIGINT FROM \(v.tableName)\(whereSQL)")
    if search.isEmpty == false { for i in 1...names.count { try count.bind(search, at: i) } }
    let total = try count.read()[0].cast(to: Int.self)[0] ?? 0
    let statement = try PreparedStatement(
      connection: c,
      query:
        "SELECT \(names.map { "CAST(\($0) AS VARCHAR)" }.joined(separator:",")), \(rowReference) FROM \(v.tableName)\(whereSQL)\(order) LIMIT \(limit) OFFSET \(offset)"
    )
    if search.isEmpty == false { for i in 1...names.count { try statement.bind(search, at: i) } }
    let result = try statement.read()
    try Task.checkCancellation()
    let rows = (0..<result.rowCount).map { index in
      DataRow(id: offset + index,
        cells: (0..<names.count).map { result[$0].cast(to: String.self)[index] },
        sourceRowID: result[names.count].cast(to: Int.self)[index])
    }
    return DataPage(rows: rows, matchingRows: total)
  }
  public func profile(datasetID: UUID) throws -> [ColumnProfile] {
    let (c, _, _) = try context()
    let v = try version(datasetID)
    return try v.columns.map { col in
      try Task.checkCancellation()
      let n = try column(col.name, in: v)
      let numeric = col.isNumeric
      let finite =
        numeric ? "CASE WHEN isfinite(TRY_CAST(\(n) AS DOUBLE)) THEN \(n) ELSE NULL END" : n
      let values =
        numeric
        ? ",avg(\(finite))::DOUBLE,median(\(finite))::DOUBLE,stddev_samp(\(finite))::DOUBLE,quantile_cont(\(finite),0.25)::DOUBLE,quantile_cont(\(finite),0.75)::DOUBLE"
        : ",NULL::DOUBLE,NULL::DOUBLE,NULL::DOUBLE,NULL::DOUBLE,NULL::DOUBLE"
      let r = try c.read(
        "SELECT count(*)::BIGINT,count(\(finite))::BIGINT,count(DISTINCT \(finite))::BIGINT,CAST(min(\(finite)) AS VARCHAR),CAST(max(\(finite)) AS VARCHAR)\(values) FROM \(v.tableName)"
      )
      return ColumnProfile(
        column: col, total: r[0].cast(to: Int.self)[0] ?? 0, valid: r[1].cast(to: Int.self)[0] ?? 0,
        distinct: r[2].cast(to: Int.self)[0] ?? 0, minimum: r[3].cast(to: String.self)[0],
        maximum: r[4].cast(to: String.self)[0], mean: r[5].cast(to: Double.self)[0],
        median: r[6].cast(to: Double.self)[0], sd: r[7].cast(to: Double.self)[0],
        q1: r[8].cast(to: Double.self)[0], q3: r[9].cast(to: Double.self)[0])
    }
  }
  public func transform(datasetID: UUID, operation: Transformation, castApproval: CastApproval? = nil) throws -> DatasetVersion {
    let (c, _, p) = try context()
    let v = try version(datasetID)
    var out = DatasetVersion(
      name: v.name, sourceID: v.sourceID, parentID: v.id, operation: operation)
    let sql: String
    var parameter: String?
    switch operation {
    case .filter(let name, let op, let value):
      let n = try column(name, in: v)
      let predicate: String
      switch op {
      case .isNull: predicate = "\(n) IS NULL"
      case .contains:
        predicate = "contains(CAST(\(n) AS VARCHAR), ?)"
        parameter = value
      default:
        let symbol =
          switch op {
          case .equal: "="
          case .notEqual: "<>"
          case .greater: ">"
          default: "<"
          }
        let type = try safeColumnType(name, v)
        predicate = "\(n) \(symbol) CAST(? AS \(type))"
        parameter = value
      }
      sql = "SELECT * FROM \(v.tableName) WHERE \(predicate)"
    case .select(let columns):
      guard columns.isEmpty == false, Set(columns).count == columns.count else {
        throw VapulaError.invalid("Select at least one distinct column.")
      }
      sql =
        "SELECT \(try columns.map{try column($0,in:v)}.joined(separator:",")) FROM \(v.tableName)"
    case .rename(let name, let newName):
      _ = try column(name, in: v)
      guard
        v.columns.contains(where: { $0.name.caseInsensitiveCompare(newName) == .orderedSame })
          == false
      else { throw VapulaError.invalid("Column name already exists.") }
      sql =
        "SELECT \(try v.columns.map{ $0.name==name ? "\(try column(name,in:v)) AS \(try SQL.identifier(newName))" : try column($0.name,in:v) }.joined(separator:",")) FROM \(v.tableName)"
    case .cast(let name, let type):
      _ = try column(name, in: v)
      let impact = try castImpact(datasetID: datasetID, column: name, type: type)
      guard impact.newNulls == 0 || castApproval == impact.approval else {
        throw VapulaError.invalid("La conversión de «\(name)» produciría \(impact.newNulls) nuevos NULL. Revisa el impacto en el inspector y confirma esta versión de entrada antes de ejecutarla.")
      }
      sql =
        "SELECT * REPLACE (TRY_CAST(\(try column(name,in:v)) AS \(type.rawValue)) AS \(try SQL.identifier(name))) FROM \(v.tableName)"
    case .derive(let name, let op, let value, let newName):
      guard value.isFinite, op != .divide || value != 0,
        v.columns.contains(where: { $0.name.caseInsensitiveCompare(newName) == .orderedSame })
          == false
      else {
        throw VapulaError.invalid(
          "Use a new name and a finite constant; division by zero is not permitted.")
      }
      let symbol =
        switch op {
        case .add: "+"
        case .subtract: "-"
        case .multiply: "*"
        case .divide: "/"
        }
      sql =
        "SELECT *, TRY_CAST(\(try column(name,in:v)) AS DOUBLE) \(symbol) \(value) AS \(try SQL.identifier(newName)) FROM \(v.tableName)"
    case .sort(let name, let ascending):
      sql =
        "SELECT * FROM \(v.tableName) ORDER BY \(try column(name,in:v)) \(ascending ? "ASC":"DESC") NULLS LAST"
    case .aggregate(let group, let name, let function):
      let g = try column(group, in: v)
      let n = try column(name, in: v)
      let f =
        switch function {
        case .mean: "avg"
        case .minimum: "min"
        case .maximum: "max"
        case .sum: "sum"
        case .count: "count"
        }
      sql =
        "SELECT \(g), \(f)(\(n)) AS \(try SQL.identifier("\(function.rawValue)_\(name)")) FROM \(v.tableName) GROUP BY \(g)"
    case .missing, .addColumn, .appendRow, .editCell, .removeRows:
      sql = try cleaningQuery(operation, version: v, connection: c)
    }
    try c.execute("BEGIN TRANSACTION")
    do {
      let statement = try PreparedStatement(
        connection: c, query: "CREATE TABLE \(out.tableName) AS \(sql)")
      if let parameter { try statement.bind(parameter, at: 1) }
      _ = try statement.execute()
      out = try metadata(out, using: c)
      try Task.checkCancellation()
      try c.execute("COMMIT")
    } catch {
      try? c.execute("ROLLBACK")
      throw error
    }
    var updated = p
    updated.datasets.append(out)
    do { try persist(updated) } catch {
      try? c.execute("DROP TABLE \(out.tableName)")
      throw error
    }
    return out
  }
  private func safeColumnType(_ name: String, _ v: DatasetVersion) throws -> String {
    guard let definition = v.columns.first(where: { $0.name == name }) else {
      throw VapulaError.invalid("Unknown column.")
    }
    if definition.isNumeric { return "DOUBLE" }
    if definition.physicalType == "DATE" { return "DATE" }
    return "VARCHAR"
  }
  public func exportData(datasetID: UUID, to url: URL, parquet: Bool) throws {
    guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) == false else {
      throw VapulaError.invalid("Choose a new export filename. Existing files are protected.")
    }
    let (c, _, _) = try context()
    let v = try version(datasetID)
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".vapula-\(UUID()).tmp")
    defer { try? FileManager.default.removeItem(at: temporary) }
    try c.execute(
      "COPY \(v.tableName) TO \(SQL.literal(temporary.path)) (FORMAT \(parquet ? "PARQUET" : "CSV"), \(parquet ? "COMPRESSION ZSTD" : "HEADER true"))"
    )
    try Task.checkCancellation()
    try FileManager.default.moveItem(at: temporary, to: url)
  }
}
