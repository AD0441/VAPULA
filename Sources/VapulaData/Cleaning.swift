import Foundation
import VapulaCore

extension DataEngine {
  func missingPredicate(_ definition: ColumnDefinition, policy: MissingPolicy) throws -> String {
    let name = try SQL.identifier(definition.name)
    var conditions = ["\(name) IS NULL"]
    if policy.blankText, definition.physicalType == "VARCHAR" {
      conditions.append("trim(\(name), \(try SQL.literal(" \t\r\n")))=''")
    }
    if policy.nonFiniteNumbers, definition.isNumeric {
      conditions.append("NOT isfinite(TRY_CAST(\(name) AS DOUBLE))")
    }
    return "(" + conditions.joined(separator: " OR ") + ")"
  }
  public func missingImpact(datasetID: UUID, columns: [String], policy: MissingPolicy = MissingPolicy()) throws -> MissingImpact {
    let (c, _, _) = try context(); let v = try version(datasetID)
    guard !columns.isEmpty, Set(columns).count == columns.count else { throw VapulaError.invalid("Selecciona columnas distintas para revisar.") }
    var counts: [String: Int] = [:]; var predicates: [String] = []
    for name in columns {
      _ = try column(name, in: v)
      let definition = v.columns.first { $0.name == name }!
      let predicate = try missingPredicate(definition, policy: policy)
      predicates.append(predicate)
      counts[name] = try scalarInt("SELECT count(*)::BIGINT FROM \(v.tableName) WHERE \(predicate)", c)
      try Task.checkCancellation()
    }
    let rows = try scalarInt("SELECT count(*)::BIGINT FROM \(v.tableName) WHERE \(predicates.joined(separator: " OR "))", c)
    return MissingImpact(datasetID: datasetID, counts: counts, affectedRows: rows, totalRows: v.rowCount)
  }
  /// Whitelist physical types; never interpolate a type string from a manifest unchecked.
  func editableType(_ definition: ColumnDefinition) throws -> String {
    let type = definition.physicalType
    let types = ["VARCHAR", "BOOLEAN", "DATE", "TIME", "TIMESTAMP", "TIMESTAMPTZ", "TIMESTAMP WITH TIME ZONE", "TINYINT", "SMALLINT", "INTEGER", "BIGINT", "HUGEINT", "UTINYINT", "USMALLINT", "UINTEGER", "UBIGINT", "UHUGEINT", "FLOAT", "DOUBLE", "REAL"]
    if types.contains(type) { return type }
    if type.hasPrefix("DECIMAL("), type.hasSuffix(")") {
      let parts = type.dropFirst(8).dropLast().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      if parts.count == 2, let precision = Int(parts[0]), let scale = Int(parts[1]),
        (1...38).contains(precision), (0...precision).contains(scale) {
        return "DECIMAL(\(precision),\(scale))"
      }
    }
    throw VapulaError.invalid("Convierte primero \(definition.name) a un tipo escalar editable (texto, número o fecha).")
  }
  func typedLiteral(_ value: String?, definition: ColumnDefinition, connection c: Connection) throws -> String {
    guard let value else { return "NULL" }
    let type = try editableType(definition)
    guard value.utf8.count <= 1_000_000 else { throw VapulaError.invalid("El valor supera el tamaño permitido.") }
    let expression = "CAST(\(try SQL.literal(value)) AS \(type))"
    // Strict CAST refuses incompatible values; numerical infinities are not silently introduced.
    if definition.isNumeric {
      let check = try c.read("SELECT isfinite(CAST(\(expression) AS DOUBLE))")
      guard check[0].cast(to: Bool.self)[0] == true else { throw VapulaError.invalid("El valor debe ser numérico y finito.") }
    } else { _ = try c.read("SELECT \(expression)") }
    return expression
  }
  func requireRowIdentity(_ v: DatasetVersion) throws {
    guard !v.columns.contains(where: { $0.name.caseInsensitiveCompare("rowid") == .orderedSame }) else {
      throw VapulaError.invalid("Renombra la columna rowid antes de corregir o retirar filas: ese nombre oculta el identificador interno de DuckDB.")
    }
  }
  func cleaningQuery(_ operation: Transformation, version v: DatasetVersion, connection c: Connection) throws -> String {
    switch operation {
    case .missing(let columns, let action, let policy):
      let impact = try missingImpact(datasetID: v.id, columns: columns, policy: policy)
      let selected = Set(columns)
      let definitions = v.columns.filter { selected.contains($0.name) }
      if action == .dropRows {
        let predicates = try definitions.map { try missingPredicate($0, policy: policy) }
        return "SELECT * FROM \(v.tableName) WHERE NOT (\(predicates.joined(separator: " OR ")))"
      }
      if action == .dropColumns {
        let remaining = v.columns.filter { (impact.counts[$0.name] ?? 0) == 0 }
        guard !remaining.isEmpty else { throw VapulaError.invalid("La operación retiraría todas las columnas. Selecciona menos columnas.") }
        return "SELECT \(try remaining.map { try SQL.identifier($0.name) }.joined(separator: ",")) FROM \(v.tableName)"
      }
      var expressions: [String] = []
      for definition in v.columns {
        let name = try SQL.identifier(definition.name)
        guard selected.contains(definition.name), (impact.counts[definition.name] ?? 0) > 0 else { expressions.append(name); continue }
        let predicate = try missingPredicate(definition, policy: policy)
        let replacement: String
        let original: String
        switch action {
        case .mean, .median:
          guard definition.isNumeric else { throw VapulaError.invalid("La media y la mediana requieren columnas numéricas: \(definition.name).") }
          let function = action == .mean ? "avg" : "median"
          let result = try c.read("SELECT \(function)(CAST(\(name) AS DOUBLE))::DOUBLE FROM \(v.tableName) WHERE NOT \(predicate)")
          guard let value = result[0].cast(to: Double.self)[0], value.isFinite else {
            throw VapulaError.invalid("\(definition.name) no tiene valores observados suficientes. Elige un valor indicado o retira los ausentes.")
          }
          replacement = String(value); original = "CAST(\(name) AS DOUBLE)"
        case .mode:
          _ = try editableType(definition)
          let result = try c.read("SELECT CAST(\(name) AS VARCHAR) FROM \(v.tableName) WHERE NOT \(predicate) GROUP BY \(name) ORDER BY count(*) DESC, \(name) ASC LIMIT 1")
          guard let value = result.rowCount > 0 ? result[0].cast(to: String.self)[0] : nil else {
            throw VapulaError.invalid("\(definition.name) no tiene valores observados para calcular la moda.")
          }
          replacement = try typedLiteral(value, definition: definition, connection: c); original = name
        case .constant(let value):
          replacement = try typedLiteral(value, definition: definition, connection: c); original = name
        default: throw VapulaError.invalid("Acción de ausentes no válida.")
        }
        expressions.append("CASE WHEN \(predicate) THEN \(replacement) ELSE \(original) END AS \(name)")
      }
      return "SELECT \(expressions.joined(separator: ",")) FROM \(v.tableName)"
    case .addColumn(let name, let type, let value):
      guard !v.columns.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { throw VapulaError.invalid("Ya existe una columna con ese nombre.") }
      let identifier = try SQL.identifier(name)
      let definition = ColumnDefinition(name: name, physicalType: type.rawValue)
      let expression = try typedLiteral(value, definition: definition, connection: c)
      return "SELECT *, CAST(\(expression) AS \(type.rawValue)) AS \(identifier) FROM \(v.tableName)"
    case .appendRow(let values):
      guard Set(values.keys).isSubset(of: Set(v.columns.map(\.name))) else { throw VapulaError.invalid("La fila contiene columnas desconocidas.") }
      let expressions = try v.columns.map { try typedLiteral(values[$0.name] ?? nil, definition: $0, connection: c) }
      return "SELECT * FROM \(v.tableName) UNION ALL SELECT \(expressions.joined(separator: ","))"
    case .editCell(let rowID, let columnName, let value):
      try requireRowIdentity(v)
      guard rowID >= 0, try scalarInt("SELECT count(*)::BIGINT FROM \(v.tableName) WHERE rowid=\(rowID)", c) == 1 else { throw VapulaError.invalid("La fila ya no pertenece a esta versión.") }
      _ = try column(columnName, in: v)
      let expressions = try v.columns.map { definition -> String in
        let name = try SQL.identifier(definition.name)
        guard definition.name == columnName else { return name }
        let replacement = try typedLiteral(value, definition: definition, connection: c)
        return "CASE WHEN rowid=\(rowID) THEN \(replacement) ELSE \(name) END AS \(name)"
      }
      return "SELECT \(expressions.joined(separator: ",")) FROM \(v.tableName) ORDER BY rowid"
    case .removeRows(let rowIDs):
      try requireRowIdentity(v)
      let ids = Set(rowIDs).sorted()
      guard !ids.isEmpty, ids.count <= 10_000, ids.allSatisfy({ $0 >= 0 }) else { throw VapulaError.invalid("Selecciona entre 1 y 10.000 filas válidas de la versión actual.") }
      let list = ids.map(String.init).joined(separator: ",")
      guard try scalarInt("SELECT count(*)::BIGINT FROM \(v.tableName) WHERE rowid IN (\(list))", c) == ids.count else { throw VapulaError.invalid("Una de las filas seleccionadas no pertenece a esta versión.") }
      return "SELECT * FROM \(v.tableName) WHERE rowid NOT IN (\(list)) ORDER BY rowid"
    default: throw VapulaError.invalid("Operación de limpieza no válida.")
    }
  }
}
