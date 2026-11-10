import SwiftUI
import VapulaReports

struct ReportExportView: View {
  @Bindable var workspace: Workspace
  let request: ReportExportRequest
  @State private var scope: ReportScope
  @State private var format: ReportExportFormat
  init(workspace: Workspace, request: ReportExportRequest) {
    self.workspace = workspace; self.request = request
    _scope = State(initialValue: request.scope); _format = State(initialValue: request.format)
  }
  private var scopes: [ReportScope] { request.scope == .project ? [.project] : [request.scope, .project] }
  private var plan: Result<ReportPlan, Error> {
    Result {
      guard let project = workspace.project else { throw CancellationError() }
      return try ReportSelection.plan(project: project, workflow: workspace.workflow, scope: scope, format: format)
    }
  }
  var body: some View {
    let preview = plan
    VStack(alignment: .leading, spacing: 20) {
      Text(L("Exportar informe")).font(.title2.weight(.semibold))
      Picker(L("Qué incluir"), selection: $scope) {
        ForEach(scopes, id: \.self) { Text(workspace.reportScopeTitle($0)).tag($0) }
      }
      Picker(L("Formato"), selection: $format) {
        Text(L("PDF")).tag(ReportExportFormat.pdf)
        Text(L("Markdown + imágenes")).tag(ReportExportFormat.markdown)
        Text(L("CSV de resultados")).tag(ReportExportFormat.csv)
      }
      switch preview {
      case .success(let plan):
        VStack(alignment: .leading, spacing: 9) {
          if format == .csv {
            Text(L("Resultados con métricas: \(plan.project.results.count)")).font(.headline)
            Text(T(scope == .project
              ? "CSV reúne las métricas guardadas del proyecto, incluidos los resultados históricos."
              : "CSV reúne las métricas de los análisis ejecutados de esta selección."))
          } else {
            Text(L("Resultados: \(plan.project.results.count) · Hallazgos: \(plan.project.findings.count) · Gráficos: \(plan.charts.count)")).font(.headline)
            Text(T(scope == .project
              ? "Todos los resultados y hallazgos guardados del proyecto, incluidos los históricos. Los gráficos corresponden a cajas ejecutadas."
              : "Solo las salidas de esta selección y sus versiones de origen. Los resultados de otras ramas quedan fuera."))
            if plan.omittedCharts > 0 { Text(L("Gráficos pendientes excluidos: \(plan.omittedCharts). Actualiza sus cajas para incluirlos.")) }
          }
          if format == .markdown { Text(L("Las imágenes PNG asociadas deben viajar junto al archivo Markdown.")) }
          Text(L("Elige un nombre nuevo para conservar los archivos existentes.")).foregroundStyle(.secondary)
          if !workspace.inspectorDrafts.isEmpty {
            Text(L("Los borradores del inspector no se ejecutan al exportar.")).foregroundStyle(.secondary)
          }
        }.font(.callout).fixedSize(horizontal: false, vertical: true)
      case .failure(let error):
        Label(D(error.localizedDescription), systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
      }
      HStack {
        Button(L("Cancelar")) { workspace.reportExportRequest = nil }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L("Elegir destino…")) { workspace.confirmReportExport(scope: scope, format: format) }
          .keyboardShortcut(.defaultAction).disabled(exportUnavailable(preview))
      }
    }.padding(26).frame(width: 520)
  }
  private func exportUnavailable(_ preview: Result<ReportPlan, Error>) -> Bool {
    if case .failure = preview { true } else { false }
  }
}
