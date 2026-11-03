import AppKit
import SwiftUI
import VapulaCore
import VapulaData
import VapulaReports

struct ReportExportRequest: Identifiable {
  let id = UUID()
  let scope: ReportScope
  let format: ReportExportFormat
}
extension Workspace {
  func requestReportExport(scope: ReportScope? = nil, format: ReportExportFormat = .pdf) {
    guard !busy, project != nil else { return }
    let selection = workflowNode.flatMap { [.analyze, .quality, .chart, .report].contains($0.kind) ? ReportScope.node($0.id) : nil }
    reportExportRequest = ReportExportRequest(scope: scope ?? selection ?? .project, format: format)
  }
  func exportWorkflowReport(nodeID: UUID, format: ReportExportFormat) {
    requestReportExport(scope: .node(nodeID), format: format)
  }
  func reportScopeTitle(_ scope: ReportScope) -> String {
    switch scope {
    case .project: L("Proyecto completo")
    case .node(let id): L("Caja: \(workflow.nodes.first { $0.id == id }?.displayName ?? T("No disponible"))")
    case .result: L("Resultado individual")
    }
  }
  func confirmReportExport(scope: ReportScope, format: ReportExportFormat) {
    guard !busy, let project else { return }
    let plan: ReportPlan
    do { plan = try ReportSelection.plan(project: project, workflow: workflow, scope: scope) }
    catch { self.error = error.localizedDescription; return }
    let title = reportScopeTitle(scope)
    let profiles = scope == .project ? self.profiles : []
    let profileID = datasetID
    reportExportRequest = nil
    Task { @MainActor in
      await Task.yield()
      guard !self.busy, self.project?.id == project.id else { return }
      let panel = NSSavePanel()
      panel.title = L("Exportar · \(title)")
      panel.nameFieldStringValue = L("informe\(format.fileExtension)")
      guard panel.runModal() == .OK, let url = panel.url else { return }
      self.run(L("Exportando · \(title)…")) {
        var figures: [ReportFigure] = []
        if format != .csv {
          for job in plan.charts {
            try Task.checkCancellation()
            let output = try await self.engine.workflowChart(datasetID: job.datasetID, request: job.request)
            figures.append(try self.reportFigure(output))
          }
        }
        switch format {
        case .pdf: try PDFReport.data(project: plan.project, figures: figures).write(to: url, options: .withoutOverwriting)
        case .markdown: try Reports.writeMarkdown(plan.project, profiles: profiles, profileDatasetID: profileID, figures: figures, to: url)
        case .csv: try Reports.writeNew(Reports.csv(plan.project.results), to: url)
        }
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
