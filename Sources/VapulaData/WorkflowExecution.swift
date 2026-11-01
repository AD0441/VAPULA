import Foundation
import VapulaCore

public struct WorkflowChartOutput: Sendable {
  public var datasetID: UUID
  public var request: WorkflowChart
  public var histogram: [ChartPoint]
  public var scatter: [ChartPoint]
  public var frequencies: [Frequency]
  public var box: BoxSummary?
  public var binWidth: Double?
}
public struct WorkflowExecution: Sendable {
  public var project: VapulaProject
  public var charts: [UUID: WorkflowChartOutput]
}
extension DataEngine {
  public func saveWorkflow(_ workflow: DataWorkflow) throws {
    var project = try snapshot()
    try workflow.validate(datasetIDs: Set(project.datasets.map(\.id)), resultIDs: Set(project.results.map(\.id)))
    project.workflow = workflow
    try persist(project)
  }
  public func executeWorkflow(_ document: DataWorkflow, through target: UUID? = nil) throws -> WorkflowExecution {
    var workflow = document
    let current = try snapshot()
    try workflow.validate(datasetIDs: Set(current.datasets.map(\.id)), resultIDs: Set(current.results.map(\.id)))
    if let target, workflow.nodes.first(where: { $0.id == target })?.kind != .data { workflow.invalidate(target) }
    let order = try workflow.executionOrder(through: target)
    var charts: [UUID: WorkflowChartOutput] = [:]
    try saveWorkflow(workflow)
    for id in order {
      try Task.checkCancellation()
      guard let index = workflow.nodes.firstIndex(where: { $0.id == id }) else { continue }
      var node = workflow.nodes[index]
      let isChart = node.kind == .chart
      guard node.dirty || isChart || id == target else { continue }
      do {
        func inputVersion() throws -> UUID {
          guard let parentID = node.inputs.first,
            let parent = workflow.nodes.first(where: { $0.id == parentID }),
            parent.kind.suppliesData, !parent.dirty, let versionID = parent.outputDatasetID else {
            throw VapulaError.invalid("Conecta una versión de datos válida y ejecuta sus pasos anteriores.")
          }
          _ = try version(versionID)
          return versionID
        }
        switch node.task {
        case .data(let versionID):
          _ = try version(versionID); node.outputDatasetID = versionID
        case .prepare(let operation):
          guard let operation else { throw VapulaError.invalid("Configura la operación en el inspector antes de ejecutar.") }
          let result = try transform(datasetID: inputVersion(), operation: operation)
          node.outputDatasetID = result.id
        case .analyze(let specification):
          guard let specification else { throw VapulaError.invalid("Elige la prueba y sus variables en el inspector.") }
          let result = try analyze(datasetID: inputVersion(), specification: specification)
          node.outputResultID = result.id
        case .quality(let rules):
          guard let rules else { throw VapulaError.invalid("Configura las reglas de calidad en el inspector.") }
          node.qualityFindings = try audit(datasetID: inputVersion(), rules: rules)
        case .chart(let request):
          guard let request else { throw VapulaError.invalid("Elige las variables del gráfico en el inspector.") }
          charts[id] = try workflowChart(datasetID: inputVersion(), request: request)
        case .report:
          guard !node.inputs.isEmpty, node.inputs.allSatisfy({ input in
            workflow.nodes.contains { $0.id == input && !$0.dirty }
          }) else { throw VapulaError.invalid("Conecta y ejecuta las salidas que quieres reunir en el informe.") }
        }
        if node.kind != .data {
          for descendant in workflow.descendants(of: id) where descendant != id {
            if let child = workflow.nodes.firstIndex(where: { $0.id == descendant }) { workflow.nodes[child].dirty = true }
          }
        }
        node.dirty = false; node.lastError = nil
        workflow.nodes[index] = node
        try saveWorkflow(workflow)
      } catch {
        workflow.nodes[index].lastError = error is CancellationError ? "Operación cancelada" : error.localizedDescription
        workflow.nodes[index].dirty = true
        try? saveWorkflow(workflow)
        throw error
      }
    }
    return WorkflowExecution(project: try snapshot(), charts: charts)
  }
  public func workflowChart(datasetID: UUID, request: WorkflowChart) throws -> WorkflowChartOutput {
    let v = try version(datasetID)
    guard let column = v.columns.first(where: { $0.name == request.x }) else { throw VapulaError.invalid("Elige una variable X del conjunto de entrada.") }
    var request = request; request.style = request.style.normalized()
    let paired = [.scatter, .line, .area].contains(request.style.kind)
    if paired {
      guard column.isNumeric, v.columns.contains(where: { $0.name == request.y && $0.isNumeric }) else {
        throw VapulaError.invalid("Este gráfico necesita dos variables numéricas.")
      }
    } else { request.y = "" }
    if [.histogram, .boxplot].contains(request.style.kind), !column.isNumeric { throw VapulaError.invalid("El histograma y el boxplot necesitan una variable numérica.") }
    let profile = try profile(datasetID: datasetID).first { $0.column.name == request.x }
    let frequencies = try frequencies(datasetID: datasetID, column: request.x)
    let histogram = column.isNumeric ? try histogram(datasetID: datasetID, column: request.x, bins: request.style.binCount) : []
    let box = column.isNumeric ? try boxplot(datasetID: datasetID, column: request.x) : nil
    let scatter = paired ? try scatter(datasetID: datasetID, x: request.x, y: request.y) : []
    let width: Double?
    if let low = profile?.minimum.flatMap(Double.init), let high = profile?.maximum.flatMap(Double.init), high > low {
      let candidate = (high - low) / Double(request.style.binCount)
      width = candidate.isFinite ? candidate : nil
    } else { width = nil }
    return WorkflowChartOutput(datasetID: datasetID, request: request, histogram: histogram, scatter: scatter, frequencies: frequencies, box: box, binWidth: width)
  }
}
