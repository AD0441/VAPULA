import SwiftUI
import VapulaCore

struct ResultsView: View {
  let workspace: Workspace
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Text(L("Resultados con procedencia")).font(.title2.weight(.semibold))
        Spacer()
        ReportExportMenu(workspace: workspace, result: nil)
      }
      if let results = workspace.project?.results, results.isEmpty == false {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(results.reversed()) { result in
              AnalysisResultView(result: result, workspace: workspace)
              Divider()
            }
          }
        }
      } else {
        ContentUnavailableView(
          L("Todavía no hay análisis"), systemImage: "doc.text",
          description: Text(
            L("Calcula un análisis en Estadística. Se conservará junto con su versión de datos y parámetros.")
          ))
      }
    }.padding(28)
  }
}
struct ReportExportMenu: View {
  let workspace: Workspace
  let result: AnalysisResult?
  var body: some View {
    Menu(T(result == nil ? "Exportar informe" : "Exportar resultado")) {
      Button(L("PDF…")) { workspace.exportReport(format: .pdf, result: result) }
      Button(L("Markdown (.md)…")) { workspace.exportReport(format: .markdown, result: result) }
      Button(L("CSV…")) { workspace.exportReport(format: .csv, result: result) }
    }.fixedSize().disabled(workspace.busy)
  }
}
struct AnalysisResultView: View {
  let result: AnalysisResult
  let workspace: Workspace
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(T(result.specification.method.title)).font(.title3.weight(.semibold))
        Spacer()
        ReportExportMenu(workspace: workspace, result: result)
      }
      Text(
        L("\(result.specification.variableSummary) · n válido: \(result.validCount) · excluidos: \(result.excludedCount)")
      ).font(.callout)
      HStack {
        Text(
          L("Dataset: \(result.datasetID.uuidString.prefix(8)) · α: \(result.specification.alpha) · \(result.createdAt.formatted(date:.abbreviated,time:.shortened))")
        ).font(.caption).foregroundStyle(.secondary)
        Button(L("Usar versión de origen")) { workspace.useVersion(result.datasetID, section: .data) }
          .disabled(workspace.busy)
      }
      if let p = result.metrics["p_two_sided"] ?? result.metrics["p_value"] {
        Text(
          p < result.specification.alpha
            ? "Se rechaza H0 al nivel α elegido. Revisa el tamaño de efecto y los supuestos antes de interpretar su importancia."
            : "No se rechaza H0 al nivel α elegido. Esto no demuestra equivalencia ni ausencia de efecto."
        ).font(.callout).padding(.vertical, 6)
      }
      Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 8) {
        ForEach(MetricPresentation.visibleKeys(result.metrics), id: \.self) { key in
          GridRow {
            Text(T(MetricPresentation.title(key))).foregroundStyle(.secondary)
            Text(result.metrics[key].map { String(format: "%.10g", $0) } ?? "—").monospacedDigit()
              .textSelection(.enabled)
          }
        }
      }.padding(.vertical, 6)
      DisclosureGroup(L("Método, supuestos y advertencias")) {
        VStack(alignment: .leading, spacing: 10) {
          Text(D(result.procedure)).font(.callout).textSelection(.enabled)
          ForEach(result.warnings, id: \.self) {
            Label($0, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
          }
        }.padding(.top, 10)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
