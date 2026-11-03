import AppKit
import SwiftUI
import VapulaCore
import VapulaData

enum WorkbenchInk {
  static let accent = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(red: 0.48, green: 0.76, blue: 0.65, alpha: 1)
      : NSColor(red: 0.22, green: 0.40, blue: 0.35, alpha: 1)
  })
  static let warning = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(red: 0.91, green: 0.69, blue: 0.35, alpha: 1)
      : NSColor(red: 0.58, green: 0.35, blue: 0.08, alpha: 1)
  })
}
struct WorkbenchNodeCard: View {
  let node: WorkflowNode
  let workspace: Workspace
  private var version: DatasetVersion? { node.outputDatasetID.flatMap { id in workspace.project?.datasets.first { $0.id == id } } }
  private var result: AnalysisResult? { node.outputResultID.flatMap { id in workspace.project?.results.first { $0.id == id } } }
  private var configured: Bool { node.task.configured && (node.kind == .data || !node.inputs.isEmpty) }
  private var status: String {
    if node.lastError != nil { return "Revisar" }
    if !configured { return "Configurar" }
    return node.dirty ? "Por ejecutar" : "Listo"
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 8) {
        Image(systemName: node.kind.symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(node.kind.ink)
          .frame(width: 27, height: 27).background(node.kind.ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
        Text(node.displayName).font(.system(size: 12.5, weight: .semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
      }
      Group {
        if let result {
          let key = ["mean", "p_two_sided", "p_value", "pearson_r", "spearman_rho", "r_squared"].first { result.metrics[$0] != nil }
          if let key, let value = result.metrics[key] {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
              Text(value, format: .number.precision(.significantDigits(4))).font(.system(size: 19, weight: .medium)).monospacedDigit()
              Text(T(MetricPresentation.title(key))).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
            }
          }
        } else if let chart = workspace.workflowCharts[node.id], chart.request.style.kind == .histogram, !chart.histogram.isEmpty {
          WorkbenchMiniHistogram(points: chart.histogram).frame(height: 27)
        } else if case .chart(let request?) = node.task {
          Label(L("\(T(request.style.kind.title)) · \(request.x)"), systemImage: node.dirty ? "arrow.clockwise" : "chart.bar.xaxis")
            .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
        } else if let version {
          Text(L("\(version.rowCount) filas · \(version.columns.count) columnas")).font(.system(size: 10.5)).foregroundStyle(.secondary).monospacedDigit()
        } else if let findings = node.qualityFindings {
          Text(L("\(findings.filter { $0.affectedRows > 0 }.count) reglas con candidatos")).font(.system(size: 10.5)).foregroundStyle(.secondary)
        } else if node.kind == .report {
          Label(L("Resultados conectados"), systemImage: "text.alignleft").font(.system(size: 10.5)).foregroundStyle(.secondary)
        } else { Text(L("Elige sus opciones")).font(.system(size: 10.5)).foregroundStyle(.secondary) }
      }.frame(height: 27, alignment: .leading)
      Spacer(minLength: 0)
      HStack(spacing: 4) {
        Image(systemName: node.lastError != nil ? "exclamationmark.circle" : node.dirty ? "circle.dashed" : "checkmark.circle.fill")
          .foregroundStyle(node.lastError != nil ? Color.red : node.dirty ? WorkbenchInk.warning : WorkbenchInk.accent)
        Text(T(status))
        Spacer(minLength: 0)
        if let result { Text(L("n = \(result.validCount)")).monospacedDigit() }
        else if let version { Text(L("\(version.rowCount) filas")).monospacedDigit() }
      }.font(.system(size: 9.5)).foregroundStyle(.secondary)
    }.padding(13).frame(width: 192, height: 136)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(workspace.workflowNodeID == node.id ? WorkbenchInk.accent : Color.primary.opacity(0.16), lineWidth: workspace.workflowNodeID == node.id ? 1.7 : 1))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(L("\(node.displayName). \(T(status)). \(version.map { "\($0.rowCount) filas" } ?? "")"))
  }
}
private struct WorkbenchMiniHistogram: View {
  let points: [ChartPoint]
  var body: some View {
    GeometryReader { geometry in
      let maximum = max(1, points.map(\.y).max() ?? 1)
      HStack(alignment: .bottom, spacing: 2) {
        ForEach(points) { item in
          Rectangle().fill(WorkbenchInk.accent.opacity(0.75)).frame(height: max(1, geometry.size.height * item.y / maximum))
        }
      }.frame(height: geometry.size.height, alignment: .bottom)
    }.accessibilityHidden(true)
  }
}
