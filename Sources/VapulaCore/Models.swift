import Foundation

public enum VapulaError: Error, LocalizedError, Sendable {
  case invalid(String)
  public var errorDescription: String? {
    if case .invalid(let message) = self { message } else { nil }
  }
}
public struct ColumnDefinition: Codable, Sendable, Identifiable, Equatable {
  public var id: String { name }
  public var name: String
  public var physicalType: String
  public var scale: String = "unknown"
  public var isNumeric: Bool {
    [
      "TINYINT", "SMALLINT", "INTEGER", "BIGINT", "HUGEINT", "UTINYINT", "USMALLINT", "UINTEGER",
      "UBIGINT", "UHUGEINT", "DOUBLE", "FLOAT", "REAL",
    ].contains(physicalType) || physicalType.hasPrefix("DECIMAL(")
  }
  public init(name: String, physicalType: String) {
    self.name = name
    self.physicalType = physicalType
  }
}
public struct DataSource: Codable, Sendable, Identifiable, Equatable {
  public var id: UUID
  public var name: String
  public var bytes: Int64
  public var sha256: String
  public var format: String
  public var importedAt: Date
  public var options: ImportOptions
  public init(name: String, bytes: Int64, sha256: String, format: String, options: ImportOptions) {
    id = UUID()
    self.name = name
    self.bytes = bytes
    self.sha256 = sha256
    self.format = format
    importedAt = Date()
    self.options = options
  }
}
public struct ImportOptions: Codable, Sendable, Equatable {
  public var delimiter: String = "auto"
  public var decimalSeparator: String = "."
  public var header: Bool = true
  public var allText: Bool = false
  public var dateFormat: String = ""
  public init() {}
}
public struct DatasetVersion: Codable, Sendable, Identifiable, Equatable {
  public var id: UUID
  public var name: String
  public var sourceID: UUID
  public var parentID: UUID?
  public var operation: Transformation?
  public var createdAt: Date
  public var columns: [ColumnDefinition]
  public var rowCount: Int
  public var tableName: String {
    "v_" + id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }
  public init(name: String, sourceID: UUID, parentID: UUID? = nil, operation: Transformation? = nil)
  {
    id = UUID()
    self.name = name
    self.sourceID = sourceID
    self.parentID = parentID
    self.operation = operation
    createdAt = Date()
    columns = []
    rowCount = 0
  }
}
public enum Comparison: String, Codable, Sendable, CaseIterable {
  case equal, notEqual, greater, less, contains, isNull
}
public enum Aggregate: String, Codable, Sendable, CaseIterable {
  case count, mean, sum, minimum, maximum
}
public enum Arithmetic: String, Codable, Sendable, CaseIterable {
  case add, subtract, multiply, divide
}
public enum PhysicalType: String, Codable, Sendable, CaseIterable {
  case text = "VARCHAR"
  case number = "DOUBLE"
  case integer = "BIGINT"
  case date = "DATE"
}
public enum Transformation: Codable, Sendable, Equatable {
  case filter(column: String, comparison: Comparison, value: String)
  case select(columns: [String])
  case rename(column: String, name: String)
  case cast(column: String, type: PhysicalType)
  case derive(column: String, operation: Arithmetic, value: Double, name: String)
  case sort(column: String, ascending: Bool)
  case aggregate(group: String, column: String, function: Aggregate)
  case missing(columns: [String], action: MissingAction, policy: MissingPolicy)
  case addColumn(name: String, type: PhysicalType, value: String?)
  case appendRow(values: [String: String?])
  case editCell(rowID: Int, column: String, value: String?)
  case removeRows(rowIDs: [Int])
  public var summary: String {
    switch self {
    case .filter(let c, let op, let v): "Filter: \(c) \(op.rawValue) \(v)"
    case .select(let c): "Select: \(c.joined(separator: ", "))"
    case .rename(let c, let n): "Rename: \(c) → \(n)"
    case .cast(let c, let t): "Cast: \(c) → \(t.rawValue) (TRY_CAST)"
    case .derive(let c, let op, let v, let n): "Derive: \(n) = \(c) \(op.rawValue) \(v)"
    case .sort(let c, let a): "Sort: \(c), \(a ? "ASC" : "DESC")"
    case .aggregate(let g, let c, let f): "Aggregate: \(f.rawValue)(\(c)) by \(g)"
    case .missing(let columns, let action, _): "Ausentes: \(action.title) · \(columns.joined(separator: ", "))"
    case .addColumn(let name, let type, _): "Añadir columna: \(name) · \(type.rawValue)"
    case .appendRow: "Añadir una fila"
    case .editCell(let row, let column, _): "Corregir celda: fila de origen \(row + 1) · \(column)"
    case .removeRows(let rows): "Retirar \(rows.count) filas seleccionadas"
    }
  }
}
public struct ColumnProfile: Sendable, Identifiable, Equatable {
  public var id: String { column.name }
  public var column: ColumnDefinition
  public var total: Int
  public var valid: Int
  public var distinct: Int
  public var minimum: String?
  public var maximum: String?
  public var mean: Double?
  public var median: Double?
  public var sd: Double?
  public var q1: Double?
  public var q3: Double?
  public var missing: Int { total - valid }
  public init(
    column: ColumnDefinition, total: Int, valid: Int, distinct: Int, minimum: String?,
    maximum: String?, mean: Double?, median: Double?, sd: Double?, q1: Double?, q3: Double?
  ) {
    self.column = column
    self.total = total
    self.valid = valid
    self.distinct = distinct
    self.minimum = minimum
    self.maximum = maximum
    self.mean = mean
    self.median = median
    self.sd = sd
    self.q1 = q1
    self.q3 = q3
  }
}
public struct DataRow: Sendable, Identifiable, Equatable {
  public var id: Int
  public var cells: [String?]
  public var sourceRowID: Int?
  public init(id: Int, cells: [String?], sourceRowID: Int? = nil) {
    self.id = id
    self.cells = cells
    self.sourceRowID = sourceRowID
  }
}
public struct DataPage: Sendable, Equatable {
  public var rows: [DataRow]
  public var matchingRows: Int
  public init(rows: [DataRow], matchingRows: Int) {
    self.rows = rows
    self.matchingRows = matchingRows
  }
}
public enum QualityRule: Codable, Sendable, Equatable {
  case missing(String)
  case duplicates([String])
  case outlier(String)
  case range(String, Double, Double)
  case nonFinite(String)
  case blank(String)
  public var label: String {
    switch self {
    case .missing(let c): "Missing / \(c)"
    case .duplicates(let c): "Duplicate candidates / \(c.joined(separator: ", "))"
    case .outlier(let c): "IQR candidates / \(c)"
    case .range(let c, let l, let u): "Range / \(c) [\(l), \(u)]"
    case .nonFinite(let c): "NaN / Inf / \(c)"
    case .blank(let c): "Texto vacío / \(c)"
    }
  }
}
public struct QualityFinding: Codable, Sendable, Identifiable, Equatable {
  public var id = UUID()
  public var datasetID: UUID
  public var rule: QualityRule
  public var affectedRows: Int
  public var note: String
  public init(datasetID: UUID, rule: QualityRule, affectedRows: Int) {
    self.datasetID = datasetID
    self.rule = rule
    self.affectedRows = affectedRows
    note = "Candidates for review; a detection does not establish an error."
  }
}
public enum AnalysisMethod: String, Codable, Sendable, CaseIterable {
  case descriptive, oneSampleT, pairedT, pearson, spearman, welch, anova, mannWhitney, chiSquare,
    regression
}
public struct AnalysisSpecification: Codable, Sendable, Equatable {
  public var method: AnalysisMethod
  public var x: String
  public var y: String
  public var group: String
  public var groupA: String
  public var groupB: String
  public var alpha: Double
  public var hypothesizedMean: Double?
  public init(
    method: AnalysisMethod, x: String, y: String = "", group: String = "", groupA: String = "",
    groupB: String = "", alpha: Double = 0.05, hypothesizedMean: Double = 0
  ) {
    self.method = method
    self.x = x
    self.y = y
    self.group = group
    self.groupA = groupA
    self.groupB = groupB
    self.alpha = alpha
    self.hypothesizedMean = hypothesizedMean
  }
}
public struct AnalysisResult: Codable, Sendable, Identifiable, Equatable {
  public var id = UUID()
  public var datasetID: UUID
  public var specification: AnalysisSpecification
  public var createdAt = Date()
  public var validCount: Int
  public var excludedCount: Int
  public var metrics: [String: Double]
  public var warnings: [String]
  public var procedure: String
  public init(
    datasetID: UUID, specification: AnalysisSpecification, validCount: Int, excludedCount: Int,
    metrics: [String: Double], warnings: [String], procedure: String
  ) {
    self.datasetID = datasetID
    self.specification = specification
    self.validCount = validCount
    self.excludedCount = excludedCount
    self.metrics = metrics
    self.warnings = warnings
    self.procedure = procedure
  }
}
public struct VapulaProject: Codable, Sendable, Equatable {
  public var schemaVersion = 1
  public var id = UUID()
  public var name: String
  public var createdAt = Date()
  public var modifiedAt = Date()
  public var sources: [DataSource] = []
  public var datasets: [DatasetVersion] = []
  public var findings: [QualityFinding] = []
  public var results: [AnalysisResult] = []
  public var chartConfigurations: [String: ChartConfiguration]? = [:]
  public var workflow: DataWorkflow?
  public init(name: String) { self.name = name }
}
