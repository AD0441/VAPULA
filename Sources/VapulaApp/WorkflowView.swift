import SwiftUI
import VapulaCore

struct WorkflowView: View {
  let workspace: Workspace
  @State private var selectedVersionID: UUID?
  private var selected: DatasetVersion? {
    workspace.project?.datasets.first { $0.id == (selectedVersionID ?? workspace.datasetID) }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(L("Flujo de trabajo")).font(.title2.weight(.semibold))
      Text(
        L("Fuentes, versiones y análisis conectados. Cada nodo representa un paso completado; selecciona una versión para inspeccionarla o continuar desde ella.")
      ).foregroundStyle(.secondary)
      HStack(spacing: 14) {
        WorkflowAction(
          title: "Importar", symbol: "square.and.arrow.down",
          detail: workspace.project?.sources.count == 1 ? "1 fuente" : "\(workspace.project?.sources.count ?? 0) fuentes"
        ) { workspace.chooseImport() }
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        WorkflowAction(
          title: "Preparar", symbol: "slider.horizontal.3", detail: "Versiones inmutables"
        ) { open(.preparation) }
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        WorkflowAction(title: "Analizar", symbol: "function", detail: "10 métodos generales") {
          open(.statistics)
        }
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        WorkflowAction(
          title: "Visualizar", symbol: "chart.xyaxis.line", detail: "Estilo configurable"
        ) { open(.visualization) }
        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        WorkflowAction(title: "Informe", symbol: "doc.richtext", detail: "PDF · Markdown · CSV") {
          workspace.selectedSection = .results
        }
      }.disabled(workspace.busy)
      Divider()
      if let project = workspace.project, project.datasets.isEmpty == false {
        WorkflowGraph(
          project: project, selectedID: selectedVersionID ?? workspace.datasetID,
          onSelect: { selectedVersionID = $0 }
        ).frame(maxHeight: .infinity)
        if project.datasets.count > 40 || project.results.count > 15 {
          Text(
            L("Se muestran las últimas 40 versiones y 15 análisis. El selector superior conserva el historial completo.")
          ).font(.caption).foregroundStyle(.secondary)
        }
        if let selected {
          HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
              Text(selected.operation?.summary ?? "Importación: \(selected.name)").font(.headline)
              Text(
                L("\(selected.rowCount) filas · \(selected.columns.count) columnas · \(selected.id.uuidString.prefix(8))")
              ).foregroundStyle(.secondary).font(.callout)
              Text(
                L("Origen: \(workspace.project?.sources.first{$0.id==selected.sourceID}?.name ?? "—")")
              ).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("Abrir datos")) { open(.data) }
            Button(L("Preparar versión")) { open(.preparation) }
            Button(L("Analizar versión")) { open(.statistics) }
          }.disabled(workspace.busy)
        }
      } else {
        ContentUnavailableView(
          L("El flujo empieza con tus datos"), systemImage: "point.3.connected.trianglepath.dotted",
          description: Text(
            L("Importa un archivo local. Las versiones y los análisis aparecerán conectados aquí.")))
      }
    }.padding(26)
  }
  private func open(_ section: WorkspaceSection) {
    if let id = selected?.id ?? workspace.datasetID { workspace.useVersion(id, section: section) }
  }
}
private struct WorkflowAction: View {
  let title: String
  let symbol: String
  let detail: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 6) {
        Label(title, systemImage: symbol).font(.headline)
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
    }.buttonStyle(.plain).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
  }
}
private struct WorkflowGraph: View {
  let project: VapulaProject
  let selectedID: UUID?
  let onSelect: (UUID) -> Void
  private var versions: [DatasetVersion] { Array(project.datasets.suffix(40)) }
  private var results: [AnalysisResult] { Array(project.results.suffix(15)) }
  private var locations: [UUID: CGPoint] {
    var depths: [UUID: Int] = [:]
    var rows: [Int: Int] = [:]
    var positions: [UUID: CGPoint] = [:]
    for v in versions {
      let depth = v.parentID.flatMap { depths[$0] }.map { $0 + 1 } ?? 0
      let row = rows[depth, default: 0]
      rows[depth] = row + 1
      depths[v.id] = depth
      positions[v.id] = CGPoint(x: 115 + CGFloat(depth) * 255, y: 52 + CGFloat(row) * 110)
    }
    for r in results {
      let depth = (depths[r.datasetID] ?? 0) + 1
      let row = rows[depth, default: 0]
      rows[depth] = row + 1
      positions[r.id] = CGPoint(x: 115 + CGFloat(depth) * 255, y: 52 + CGFloat(row) * 110)
    }
    return positions
  }
  var body: some View {
    let positions = locations
    let width = (positions.values.map(\.x).max() ?? 115) + 130
    let height = max(240, (positions.values.map(\.y).max() ?? 52) + 65)
    ScrollView([.horizontal, .vertical]) {
      ZStack(alignment: .topLeading) {
        Canvas { context, _ in
          for v in versions {
            if let parent = v.parentID, let start = positions[parent], let end = positions[v.id] {
              drawConnection(&context, start: start, end: end)
            }
          }
          for r in results {
            if let start = positions[r.datasetID], let end = positions[r.id] {
              drawConnection(&context, start: start, end: end)
            }
          }
        }.accessibilityHidden(true)
        ForEach(versions) { v in
          if let point = positions[v.id] {
            Button {
              onSelect(v.id)
            } label: {
              WorkflowNode(
                title: v.operation == nil ? v.name : operationTitle(v.operation),
                subtitle: "\(v.rowCount) filas · \(v.id.uuidString.prefix(6))",
                symbol: v.operation == nil ? "tablecells" : "slider.horizontal.3",
                selected: selectedID == v.id)
            }.buttonStyle(.plain).position(point)
          }
        }
        ForEach(results) { r in
          if let point = positions[r.id] {
            WorkflowNode(
              title: r.specification.method.title,
              subtitle: "n = \(r.validCount) · \(r.datasetID.uuidString.prefix(6))",
              symbol: "checkmark.circle", selected: false
            ).position(point)
          }
        }
      }.frame(width: width, height: height)
    }.background(.quaternary.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius: 12))
  }
  private func drawConnection(_ context: inout GraphicsContext, start: CGPoint, end: CGPoint) {
    let a = CGPoint(x: start.x + 105, y: start.y)
    let b = CGPoint(x: end.x - 105, y: end.y)
    var path = Path()
    path.move(to: a)
    path.addCurve(
      to: b, control1: CGPoint(x: a.x + 55, y: a.y), control2: CGPoint(x: b.x - 55, y: b.y))
    context.stroke(path, with: .color(.secondary.opacity(0.45)), lineWidth: 1.5)
  }
  private func operationTitle(_ operation: Transformation?) -> String {
    switch operation {
    case .filter: "Filtrar"
    case .select: "Seleccionar columnas"
    case .rename: "Renombrar"
    case .cast: "Convertir tipo"
    case .derive: "Columna derivada"
    case .sort: "Ordenar"
    case .aggregate: "Agrupar"
    case .missing: "Tratar ausentes"
    case .addColumn: "Añadir columna"
    case .appendRow: "Añadir fila"
    case .editCell: "Corregir celda"
    case .removeRows: "Retirar filas"
    case nil: "Importar"
    }
  }
}
private struct WorkflowNode: View {
  let title: String
  let subtitle: String
  let symbol: String
  let selected: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: symbol).font(.callout.weight(.semibold)).lineLimit(2)
      Text(subtitle).font(.caption).foregroundStyle(.secondary).monospacedDigit()
    }
    .frame(width: 178, height: 58, alignment: .leading).padding(13)
    .background(.background, in: RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10).stroke(
        selected ? Color.primary : Color.secondary.opacity(0.3), lineWidth: selected ? 2 : 1)
    )
    .accessibilityElement(children: .combine)
  }
}
