import SwiftUI
import VapulaCore
import VapulaData

struct WorkbenchPreview: View {
  @Bindable var workspace: Workspace
  @Binding var expanded: Bool
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 17) {
        ForEach(WorkbenchTab.allCases) { tab in
          Button { workspace.workflowTab = tab } label: {
            Text(T(tab.rawValue)).font(.system(size: 11.5, weight: workspace.workflowTab == tab ? .semibold : .regular))
              .foregroundStyle(workspace.workflowTab == tab ? Color.primary : .secondary).frame(height: 36)
              .overlay(alignment: .bottom) { if workspace.workflowTab == tab { Rectangle().fill(WorkbenchInk.accent).frame(height: 2) } }
          }.buttonStyle(.plain)
        }
        Spacer()
        Text(workspace.workflowNode?.displayName ?? T("Resultados guardados")).font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
        Button { expanded.toggle() } label: { Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help(L("Ampliar vista previa")).accessibilityLabel(L("Ampliar vista previa"))
      }.padding(.horizontal, 16)
      Divider()
      if workspace.workflowNode?.dirty == true {
        HStack(spacing: 5) {
          Image(systemName: "circle.dashed")
          Text(L("La salida anterior se conserva. Configura y ejecuta este paso para actualizarla."))
          Spacer()
        }.font(.system(size: 10.5)).foregroundStyle(.secondary).padding(.horizontal, 15).padding(.vertical, 5)
      }
      Group {
        switch workspace.workflowTab {
        case .data:
          WorkbenchDataPreview(workspace: workspace)
        case .result:
          if let node = workspace.workflowNode {
            if let id = node.outputResultID, let result = workspace.project?.results.first(where: { $0.id == id }) {
              WorkbenchResultPreview(workspace: workspace, result: result)
            } else if let findings = node.qualityFindings { WorkbenchQualityPreview(workspace: workspace, findings: findings) }
            else { WorkbenchPreviewHint(text: "Ejecuta una caja de análisis o calidad para consultar su resultado.", symbol: "function") }
          } else { ResultsView(workspace: workspace) }
        case .chart:
          if let id = workspace.workflowNodeID, let output = workspace.workflowCharts[id] {
            WorkbenchChartPreview(output: output)
          } else { WorkbenchPreviewHint(text: "Selecciona un gráfico y pulsa Actualizar gráfico para cargar su salida.", symbol: "chart.xyaxis.line") }
        case .report:
          if let node = workspace.workflowNode, node.kind == .report {
            WorkbenchReportPreview(workspace: workspace, node: node)
          } else { WorkbenchPreviewHint(text: "Selecciona una caja de informe para reunir y exportar las salidas conectadas.", symbol: "doc.richtext") }
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }.background(.background)
  }
}
private struct WorkbenchDataPreview: View {
  @Bindable var workspace: Workspace
  var body: some View {
    if let dataset = workspace.dataset {
      VStack(spacing: 0) {
        HStack(spacing: 8) {
          TextField(L("Buscar"), text: $workspace.search).textFieldStyle(.roundedBorder).frame(maxWidth: 175).onSubmit { workspace.reloadPage() }
          Button(action: workspace.reloadPage) { Image(systemName: "magnifyingglass") }.help(L("Buscar en todas las columnas")).accessibilityLabel(L("Buscar"))
          Spacer(minLength: 5)
          Menu(L("Editar")) {
            Button(L("Corregir una celda…")) {
              if let row = workspace.selectedDataRows.first { workspace.editRequest = DataEditRequest(kind: .cell, dataset: dataset, row: row) }
            }.disabled(workspace.selectedDataRows.count != 1)
            Button(L("Añadir fila…")) { workspace.editRequest = DataEditRequest(kind: .row, dataset: dataset) }
            Button(L("Añadir columna…")) { workspace.editRequest = DataEditRequest(kind: .column, dataset: dataset) }
            Divider()
            Button(L("Retirar filas seleccionadas…")) { workspace.editRequest = DataEditRequest(kind: .removeRows, dataset: dataset, rows: workspace.selectedDataRows) }.disabled(workspace.selectedDataRows.isEmpty)
          }
          .fixedSize()
          Menu(L("Exportar")) {
            Button(L("CSV…")) { workspace.exportData(parquet: false) }
            Button(L("Parquet…")) { workspace.exportData(parquet: true) }
          }.fixedSize()
        }.font(.system(size: 11)).controlSize(.small).padding(.horizontal, 12).padding(.vertical, 6).disabled(workspace.busy)
        DataGrid(columns: dataset.columns, rows: workspace.page.rows, onSort: workspace.sort,
          onEdit: { row, column in
            guard !workspace.busy else { return }
            workspace.editRequest = DataEditRequest(kind: .cell, dataset: dataset, row: row, column: column)
          }, onSelection: { workspace.selectedDataRows = $0 })
        HStack(spacing: 10) {
          Text(L("\(workspace.page.matchingRows) coincidencias · \(workspace.selectedDataRows.count) seleccionadas")).foregroundStyle(.secondary)
          Spacer()
          Button(L("Anterior")) { workspace.turnPage(-1) }.disabled(workspace.offset == 0 || workspace.busy)
          Text(workspace.page.rows.isEmpty ? "0 filas" : "\(workspace.offset + 1)–\(workspace.offset + workspace.page.rows.count)").monospacedDigit()
          Button(L("Siguiente")) { workspace.turnPage(1) }.disabled(workspace.offset + 100 >= workspace.page.matchingRows || workspace.busy)
        }.font(.system(size: 10)).controlSize(.mini).padding(.horizontal, 12).padding(.vertical, 5)
      }
    } else { WorkbenchPreviewHint(text: "Importa un archivo o selecciona una versión de datos.", symbol: "tablecells") }
  }
}
struct WorkbenchResultPreview: View {
  let workspace: Workspace
  let result: AnalysisResult
  private var keys: [String] {
    let priority = ["p_two_sided", "p_value", "mean", "median", "difference_a_minus_b", "mean_difference", "pearson_r", "spearman_rho", "r_squared", "t", "f", "chi_square", "df", "sample_sd"]
    return MetricPresentation.visibleKeys(result.metrics).sorted { a, b in
      let left = priority.firstIndex(of: a) ?? 99; let right = priority.firstIndex(of: b) ?? 99
      return left == right ? a < b : left < right
    }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 15) {
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text(T(result.specification.method.title)).font(.system(size: 14, weight: .semibold))
            Text(L("\(result.specification.variableSummary) · \(result.validCount) válidos · \(result.excludedCount) excluidos")).font(.system(size: 11)).foregroundStyle(.secondary)
          }
          Spacer()
          ReportExportMenu(workspace: workspace, result: result).controlSize(.small)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), alignment: .leading)], alignment: .leading, spacing: 15) {
          ForEach(keys, id: \.self) { key in
            VStack(alignment: .leading, spacing: 5) {
              Text(T(MetricPresentation.title(key))).font(.system(size: 10.5)).foregroundStyle(.secondary)
              Text(result.metrics[key].map { String(format: "%.7g", $0) } ?? "—").font(.system(size: 16, weight: .medium)).monospacedDigit().textSelection(.enabled)
            }
          }
        }
        DisclosureGroup(L("Método, supuestos y advertencias")) {
          VStack(alignment: .leading, spacing: 8) {
            Text(D(result.procedure))
            ForEach(result.warnings, id: \.self) { Text(D($0)) }
          }.font(.caption).foregroundStyle(.secondary).padding(.top, 8).textSelection(.enabled)
        }.font(.system(size: 11))
      }.padding(16)
    }
  }
}
private struct WorkbenchQualityPreview: View {
  let workspace: Workspace
  let findings: [QualityFinding]
  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        ForEach(findings) { finding in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(D(finding.rule.label)).font(.system(size: 12, weight: .medium))
              Text(L("\(finding.affectedRows) filas candidatas")).font(.system(size: 10.5)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("Ver evidencia")) { workspace.showEvidence(finding) }.controlSize(.small).disabled(finding.affectedRows == 0 || workspace.busy)
          }
        }
        Text(L("Los hallazgos son candidatos para revisión; una detección no confirma un error.")).font(.caption).foregroundStyle(.secondary)
      }.padding(16)
    }
  }
}
struct WorkbenchChartPreview: View {
  let output: WorkflowChartOutput
  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      if !output.request.style.title.isEmpty { Text(output.request.style.title).font(.system(size: 12, weight: .semibold)).lineLimit(2).help(output.request.style.title) }
      StatisticalChartView(configuration: output.request.style, histogram: output.histogram, scatter: output.scatter,
        frequencies: output.frequencies, box: output.box, xName: output.request.x, yName: output.request.y, histogramWidth: output.binWidth)
      Text(T([.scatter, .line, .area].contains(output.request.style.kind) ? "Primeros 2.000 pares finitos; sin inferir representatividad. Líneas y áreas se ordenan por X." : "Agregados del conjunto completo; frecuencias limitadas a las 30 categorías más comunes."))
        .font(.system(size: 9.5)).foregroundStyle(.secondary)
    }.padding(.horizontal, 16).padding(.vertical, 9)
  }
}
private struct WorkbenchReportPreview: View {
  let workspace: Workspace
  let node: WorkflowNode
  private var included: [WorkflowNode] {
    let ids = Set((try? workspace.workflow.executionOrder(through: node.id)) ?? [])
    return workspace.workflow.nodes.filter { ids.contains($0.id) && [.analyze, .chart, .quality].contains($0.kind) }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(node.displayName).font(.system(size: 17, weight: .semibold))
          Spacer()
          Menu(L("Exportar informe")) {
            Button(L("PDF…")) { workspace.exportWorkflowReport(nodeID: node.id, format: .pdf) }
            Button(L("Markdown (.md)…")) { workspace.exportWorkflowReport(nodeID: node.id, format: .markdown) }
            Button(L("CSV de resultados…")) { workspace.exportWorkflowReport(nodeID: node.id, format: .csv) }
          }.controlSize(.small).fixedSize().disabled(node.dirty || workspace.busy)
        }
        Text(L("\(included.count) salidas conectadas · fuentes y versiones trazables")).font(.caption).foregroundStyle(.secondary)
        ForEach(included) { item in
          Divider()
          if let id = item.outputResultID, let result = workspace.project?.results.first(where: { $0.id == id }) {
            WorkbenchResultPreview(workspace: workspace, result: result).frame(minHeight: 190)
          } else if let chart = workspace.workflowCharts[item.id] {
            WorkbenchChartPreview(output: chart).frame(height: 230)
          } else if let findings = item.qualityFindings {
            WorkbenchQualityPreview(workspace: workspace, findings: findings).frame(minHeight: 160)
          } else {
            Label(item.displayName, systemImage: item.kind.symbol).font(.callout)
            Text(L("El contenido se cargará al actualizar o exportar el informe.")).font(.caption).foregroundStyle(.secondary)
          }
        }
      }.padding(16)
    }
  }
}
struct WorkbenchPreviewHint: View {
  let text: String
  let symbol: String
  var body: some View {
    HStack(spacing: 9) { Image(systemName: symbol).font(.system(size: 18)); Text(T(text)).font(.system(size: 12)) }
      .foregroundStyle(.secondary).padding(20)
  }
}
