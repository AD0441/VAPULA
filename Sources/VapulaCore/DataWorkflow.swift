import Foundation

public enum WorkflowKind: String, Codable, Sendable, CaseIterable {
  case data, prepare, missing, quality, analyze, chart, report
  public var title: String {
    switch self {
    case .data: "Datos"; case .prepare: "Preparar"; case .missing: "Tratar ausentes"
    case .quality: "Calidad"; case .analyze: "Analizar"; case .chart: "Gráfico"; case .report: "Informe"
    }
  }
  public var symbol: String {
    switch self {
    case .data: "tablecells"; case .prepare: "slider.horizontal.3"; case .missing: "bandage"
    case .quality: "checkmark.shield"; case .analyze: "function"; case .chart: "chart.bar.xaxis"; case .report: "doc.richtext"
    }
  }
  public var suppliesData: Bool { self == .data || self == .prepare || self == .missing }
  public var compatibleNext: [WorkflowKind] {
    suppliesData ? [.prepare, .missing, .quality, .analyze, .chart] : (self == .report ? [] : [.report])
  }
}
public struct WorkflowPoint: Codable, Equatable, Sendable {
  public var x: Double; public var y: Double
  public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}
public struct WorkflowChart: Codable, Equatable, Sendable {
  public var x: String; public var y: String
  public var style: ChartConfiguration
  public init(x: String, y: String = "", style: ChartConfiguration = ChartConfiguration()) {
    self.x = x; self.y = y; self.style = style
  }
}
public enum WorkflowTask: Codable, Equatable, Sendable {
  case data(UUID)
  case prepare(Transformation?)
  case quality([QualityRule]?)
  case analyze(AnalysisSpecification?)
  case chart(WorkflowChart?)
  case report
  public var kind: WorkflowKind {
    switch self {
    case .data: .data
    case .prepare(let operation): if case .missing = operation { .missing } else { .prepare }
    case .quality: .quality; case .analyze: .analyze; case .chart: .chart; case .report: .report
    }
  }
  public var configured: Bool {
    switch self {
    case .prepare(let operation): operation != nil
    case .quality(let rules): rules != nil
    case .analyze(let specification): specification != nil
    case .chart(let chart): chart != nil
    default: true
    }
  }
}
public struct WorkflowNode: Codable, Equatable, Identifiable, Sendable {
  public var id = UUID()
  public var name: String
  public var task: WorkflowTask
  public var inputs: [UUID]
  public var position: WorkflowPoint
  public var dirty = true
  public var outputDatasetID: UUID?
  public var outputResultID: UUID?
  public var qualityFindings: [QualityFinding]?
  public var lastError: String?
  public var kind: WorkflowKind { task.kind }
  public init(name: String, task: WorkflowTask, inputs: [UUID] = [], position: WorkflowPoint) {
    self.name = name; self.task = task; self.inputs = inputs; self.position = position
    if case .data(let datasetID) = task { outputDatasetID = datasetID; dirty = false }
  }
}
public struct DataWorkflow: Codable, Equatable, Sendable {
  public var version = 1
  public var nodes: [WorkflowNode] = []
  public init() {}
  public func validate(datasetIDs: Set<UUID>, resultIDs: Set<UUID>) throws {
    guard version == 1, nodes.count <= 500, Set(nodes.map(\.id)).count == nodes.count else {
      throw VapulaError.invalid("El flujo tiene una versión no admitida, demasiados pasos o identificadores duplicados.")
    }
    let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    for node in nodes {
      guard node.position.x.isFinite, node.position.y.isFinite,
        abs(node.position.x) <= 100_000, abs(node.position.y) <= 100_000,
        node.name.count <= 180, Set(node.inputs).count == node.inputs.count else { throw VapulaError.invalid("Metadatos de nodo no válidos.") }
      if case .data(let id) = node.task {
        guard datasetIDs.contains(id), node.outputDatasetID == id, node.inputs.isEmpty else { throw VapulaError.invalid("La fuente del nodo no pertenece al proyecto.") }
      } else if node.kind != .report, node.inputs.count > 1 { throw VapulaError.invalid("Este paso admite una sola entrada de datos.") }
      if let id = node.outputDatasetID, !datasetIDs.contains(id) { throw VapulaError.invalid("La salida de datos del nodo no existe.") }
      if let id = node.outputResultID, !resultIDs.contains(id) { throw VapulaError.invalid("El resultado del nodo no existe.") }
      for input in node.inputs {
        guard let parent = byID[input], parent.kind.compatibleNext.contains(node.kind) else {
          throw VapulaError.invalid("Conecta datos a operaciones y salidas de análisis, calidad o gráficos a un informe.")
        }
      }
    }
    _ = try executionOrder()
  }
  public func executionOrder(through target: UUID? = nil) throws -> [UUID] {
    let byID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var visiting = Set<UUID>(); var visited = Set<UUID>(); var ordered: [UUID] = []
    func visit(_ id: UUID) throws {
      guard let node = byID[id] else { throw VapulaError.invalid("No se encuentra una entrada del flujo.") }
      if visited.contains(id) { return }
      guard visiting.insert(id).inserted else { throw VapulaError.invalid("La conexión crearía un ciclo.") }
      for input in node.inputs { try visit(input) }
      visiting.remove(id); visited.insert(id); ordered.append(id)
    }
    if let target { try visit(target) } else { for node in nodes { try visit(node.id) } }
    return ordered
  }
  public func descendants(of id: UUID) -> Set<UUID> {
    var found: Set<UUID> = [id]; var count = 0
    while count != found.count {
      count = found.count
      for node in nodes where node.inputs.contains(where: { found.contains($0) }) { found.insert(node.id) }
    }
    return found
  }
  public mutating func invalidate(_ id: UUID) {
    let affected = descendants(of: id)
    for index in nodes.indices where affected.contains(nodes[index].id) {
      nodes[index].dirty = true; nodes[index].lastError = nil
    }
  }
  public func insertionPosition(after source: WorkflowNode?) -> WorkflowPoint {
    let x = source.map { $0.position.x + 235 } ?? 112
    var y = source?.position.y ?? 180
    let column = nodes.filter { abs($0.position.x - x) < 220 }
    if column.contains(where: { abs($0.position.y - y) < 180 }) { y = (column.map(\.position.y).max() ?? y) + 185 }
    return WorkflowPoint(x, y)
  }
  public static func inferred(from project: VapulaProject) -> Self {
    var flow = Self(); var byDataset: [UUID: UUID] = [:]
    for version in project.datasets {
      let parent = version.parentID.flatMap { byDataset[$0] }.flatMap { id in flow.nodes.first { $0.id == id } }
      var node = WorkflowNode(name: version.operation?.displayTitle ?? version.name,
        task: parent == nil ? .data(version.id) : .prepare(version.operation),
        inputs: parent.map { [$0.id] } ?? [], position: flow.insertionPosition(after: parent))
      node.outputDatasetID = version.id; node.dirty = false
      byDataset[version.id] = node.id; flow.nodes.append(node)
    }
    for result in project.results {
      guard let input = byDataset[result.datasetID].flatMap({ id in flow.nodes.first { $0.id == id } }) else { continue }
      var node = WorkflowNode(name: result.specification.method.title, task: .analyze(result.specification), inputs: [input.id], position: flow.insertionPosition(after: input))
      node.outputResultID = result.id; node.dirty = false; flow.nodes.append(node)
    }
    return flow
  }
}
extension Transformation {
  public var displayTitle: String {
    switch self {
    case .filter: "Filtrar datos"; case .select: "Seleccionar columnas"; case .rename: "Renombrar columna"
    case .cast: "Convertir tipo"; case .derive: "Columna derivada"; case .sort: "Ordenar datos"
    case .aggregate: "Agrupar y agregar"; case .missing: "Tratar ausentes"; case .addColumn: "Añadir columna"
    case .appendRow: "Añadir fila"; case .editCell: "Corregir celda"; case .removeRows: "Retirar filas"
    }
  }
}
