import AppKit
import SwiftUI
import VapulaCore
import VapulaData
import VapulaReports

extension Workspace {
  func exportWorkflowReport(nodeID: UUID, format: ReportExportFormat) {
    guard !busy, let node = workflow.nodes.first(where: { $0.id == nodeID }), !node.dirty, project != nil else { return }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "informe\(format.fileExtension)"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run("Preparando y exportando informe…") {
      guard var snapshot = self.project else { return }
      let order = Set(try self.workflow.executionOrder(through: nodeID))
      let included = self.workflow.nodes.filter { order.contains($0.id) }
      guard included.allSatisfy({ !$0.dirty }) else { throw VapulaError.invalid("Actualiza las salidas del informe antes de exportar.") }
      let results = Set(included.compactMap(\.outputResultID))
      snapshot.results = snapshot.results.filter { results.contains($0.id) }
      snapshot.findings = included.flatMap { $0.qualityFindings ?? [] }
      var versionIDs = Set(included.compactMap(\.outputDatasetID))
      versionIDs.formUnion(snapshot.results.map(\.datasetID))
      versionIDs.formUnion(snapshot.findings.map(\.datasetID))
      var figures: [ReportFigure] = []
      if format != .csv {
        let charts = included.filter { $0.kind == .chart }
        guard charts.count <= 32 else { throw VapulaError.invalid("Selecciona hasta 32 gráficos por informe.") }
        for item in charts {
          try Task.checkCancellation()
          guard case .chart(let request?) = item.task, let input = self.workflowInput(item) else { continue }
          let output = try await self.engine.workflowChart(datasetID: input.id, request: request)
          self.workflowCharts[item.id] = output; versionIDs.insert(output.datasetID)
          figures.append(try self.reportFigure(output))
        }
      }
      let byID = Dictionary(snapshot.datasets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
      var pending = Array(versionIDs)
      while let id = pending.popLast() {
        if let parent = byID[id]?.parentID, versionIDs.insert(parent).inserted { pending.append(parent) }
      }
      snapshot.datasets = snapshot.datasets.filter { versionIDs.contains($0.id) }
      let sourceIDs = Set(snapshot.datasets.map(\.sourceID))
      snapshot.sources = snapshot.sources.filter { sourceIDs.contains($0.id) }
      switch format {
      case .pdf: try PDFReport.data(project: snapshot, figures: figures).write(to: url, options: .withoutOverwriting)
      case .markdown: try Reports.writeMarkdown(snapshot, figures: figures, to: url)
      case .csv: try Reports.writeNew(Reports.csv(snapshot.results), to: url)
      }
    }
  }
  private func reportFigure(_ output: WorkflowChartOutput) throws -> ReportFigure {
    let style = output.request.style
    let title = style.title.isEmpty ? "\(style.kind.title) · \(output.request.x)" : style.title
    let content = StatisticalChartView(configuration: style, histogram: output.histogram, scatter: output.scatter,
      frequencies: output.frequencies, box: output.box, xName: output.request.x, yName: output.request.y,
      histogramWidth: output.binWidth)
      .padding(24).frame(width: 800, height: 450).background(.white).environment(\.colorScheme, .light)
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    guard let image = renderer.cgImage,
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
      throw VapulaError.invalid("No se pudo renderizar el gráfico para el informe.")
    }
    let caption = [.scatter, .line, .area].contains(style.kind)
      ? "Primeros 2.000 pares finitos. Líneas y áreas se ordenan por X; no se infiere representatividad ni causalidad."
      : style.kind == .boxplot ? "Cuartiles tipo 7 y bigotes de 1,5 IQR. Los puntos extremos se cuentan pero no se dibujan."
      : "Agregados del conjunto completo. Las frecuencias muestran hasta 30 categorías. Nulos y no finitos se excluyen del histograma."
    return ReportFigure(title: title, datasetID: output.datasetID, caption: caption, png: data)
  }
}
