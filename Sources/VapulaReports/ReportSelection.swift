import Foundation
import VapulaCore

public enum ReportScope: Hashable, Sendable {
  case project, node(UUID), result(UUID)
}
public enum ReportExportFormat: Hashable, Sendable {
  case pdf, markdown, csv

  public var fileExtension: String {
    switch self {
    case .pdf: ".pdf"
    case .markdown: ".md"
    case .csv: ".csv"
    }
  }
}
public struct ReportChartJob: Sendable {
  public let nodeID: UUID
  public let datasetID: UUID
  public let request: WorkflowChart
}
public struct ReportPlan: Sendable {
  public var project: VapulaProject
  public let charts: [ReportChartJob]
  public let omittedCharts: Int
}
public enum ReportSelection {
  public static func plan(
    project: VapulaProject, workflow: DataWorkflow, scope: ReportScope, format: ReportExportFormat = .pdf
  ) throws -> ReportPlan {
    var snapshot = project
    let selected: [WorkflowNode]
    var omitted = 0
    switch scope {
    case .project:
      selected = workflow.nodes.filter { !$0.dirty }
      if format != .csv { omitted = workflow.nodes.filter { $0.kind == .chart && $0.dirty }.count }
    case .node(let id):
      try workflow.validate(datasetIDs: Set(project.datasets.map(\.id)), resultIDs: Set(project.results.map(\.id)))
      guard let node = workflow.nodes.first(where: { $0.id == id }), [.analyze, .quality, .chart, .report].contains(node.kind) else {
        throw VapulaError.invalid("Selecciona una caja de análisis, calidad, gráfico o informe para exportar.")
      }
      let order: Set<UUID>
      if format == .csv, node.kind != .analyze {
        // A CSV uses the connected analyses and their ancestors. A pending
        // chart or quality branch does not make an executed analysis stale.
        let inputs = Set(node.inputs)
        var analysisSteps = Set<UUID>()
        for analysis in workflow.nodes where analysis.kind == .analyze && inputs.contains(analysis.id) {
          analysisSteps.formUnion(try workflow.executionOrder(through: analysis.id))
        }
        order = analysisSteps
      } else {
        order = Set(try workflow.executionOrder(through: id))
      }
      selected = workflow.nodes.filter { order.contains($0.id) }
      guard selected.allSatisfy({ !$0.dirty }) else {
        throw VapulaError.invalid("Actualiza las salidas de la caja antes de exportar. Los borradores sin ejecutar no cambian el informe.")
      }
      let resultIDs = Set(selected.compactMap(\.outputResultID))
      snapshot.results = project.results.filter { resultIDs.contains($0.id) }
      snapshot.findings = selected.flatMap { $0.qualityFindings ?? [] }
    case .result(let id):
      guard let result = project.results.first(where: { $0.id == id }) else {
        throw VapulaError.invalid("El resultado elegido ya no pertenece al proyecto.")
      }
      selected = []; snapshot.results = [result]; snapshot.findings = []
    }
    if format == .csv {
      snapshot.findings = []
      snapshot.results.removeAll { $0.metrics.isEmpty }
      guard !snapshot.results.isEmpty else {
        throw VapulaError.invalid("Esta selección no contiene métricas para CSV. Elige un análisis ejecutado o el proyecto completo.")
      }
    }
    var jobs: [ReportChartJob] = []
    for node in selected where format != .csv && node.kind == .chart {
      guard case .chart(let request?) = node.task, let parentID = node.inputs.first,
        let parent = workflow.nodes.first(where: { $0.id == parentID }), !parent.dirty,
        let datasetID = parent.outputDatasetID, project.datasets.contains(where: { $0.id == datasetID }) else {
        throw VapulaError.invalid("El gráfico «\(node.name)» no tiene una entrada ejecutada válida. Actualiza su caja antes de exportar.")
      }
      jobs.append(ReportChartJob(nodeID: node.id, datasetID: datasetID, request: request))
    }
    guard jobs.count <= 32 else { throw VapulaError.invalid("Selecciona hasta 32 gráficos por informe. Exporta una caja Informe con menos entradas.") }
    if scope != .project {
      var ids = Set(selected.compactMap(\.outputDatasetID))
      ids.formUnion(snapshot.results.map(\.datasetID)); ids.formUnion(snapshot.findings.map(\.datasetID)); ids.formUnion(jobs.map(\.datasetID))
      let byID = Dictionary(project.datasets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
      var pending = Array(ids)
      while let id = pending.popLast() {
        guard let version = byID[id] else { throw VapulaError.invalid("Falta una versión de datos requerida por el informe.") }
        if let parent = version.parentID, ids.insert(parent).inserted { pending.append(parent) }
      }
      snapshot.datasets = project.datasets.filter { ids.contains($0.id) }
      let sources = Set(snapshot.datasets.map(\.sourceID))
      snapshot.sources = project.sources.filter { sources.contains($0.id) }
    }
    return ReportPlan(project: snapshot, charts: jobs, omittedCharts: omitted)
  }
}
