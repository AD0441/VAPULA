import SwiftUI
import VapulaCore

struct LegacyContentView: View {
  @Bindable var workspace: Workspace
  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          SealView().frame(width: 34, height: 34)
          VStack(alignment: .leading, spacing: 3) {
            Text("VAPULA").font(.headline).tracking(2)
            Text("Data & Statistical Laboratory").font(.caption2).foregroundStyle(.secondary)
          }
        }.padding(18)
        List(WorkspaceSection.allCases, selection: $workspace.selectedSection) { item in
          Label(LocalizedStringKey(item.rawValue), systemImage: item.symbol).tag(item)
        }.listStyle(.sidebar)
        VStack(alignment: .leading, spacing: 12) {
          if let project = workspace.project {
            Text(project.name).font(.subheadline.weight(.medium))
            Text("\(project.datasets.count) versiones · guardado automático").font(.caption)
              .foregroundStyle(.secondary)
          }
          Divider()
          HStack {
            SettingsLink { Label("Ajustes", systemImage: "gearshape") }
            Spacer()
            Link(destination: URL(string: "https://ko-fi.com/sebastianpasten")!) {
              Image(systemName: "cup.and.saucer").accessibilityLabel(
                "Apoyar en Ko-fi; abre el navegador")
            }
          }
          Text("Creado por Sebastián Pastén F.").font(.caption2).foregroundStyle(.secondary)
        }.buttonStyle(.plain).padding(18)
      }.navigationSplitViewColumnWidth(min: 235, ideal: 250, max: 300)
    } detail: {
      VStack(spacing: 0) {
        if let project = workspace.project, project.datasets.isEmpty == false {
          HStack {
            Text("Versión de datos").foregroundStyle(.secondary)
            Picker(
              "Versión de datos",
              selection: Binding(get: { workspace.datasetID }, set: { workspace.selectVersion($0) })
            ) {
              ForEach(project.datasets) { v in
                Text(
                  "\(v.name) · \(v.operation?.summary ?? "Import") · \(v.id.uuidString.prefix(6))"
                ).tag(Optional(v.id))
              }
            }.labelsHidden().frame(maxWidth: 620)
            Spacer()
            if let v = workspace.dataset {
              Text("\(v.rowCount) filas · \(v.columns.count) columnas").font(.callout)
                .monospacedDigit().foregroundStyle(.secondary)
            }
          }.padding(14).disabled(workspace.busy)
          Divider()
        }
        Group {
          if workspace.selectedSection == .projects {
            ProjectView(workspace: workspace)
          } else if workspace.selectedSection == .workflow {
            WorkflowView(workspace: workspace)
          } else if let dataset = workspace.dataset {
            switch workspace.selectedSection {
            case .workflow:
              WorkflowView(workspace: workspace)
            case .data: DataStudioView(workspace: workspace, dataset: dataset)
            case .preparation:
              PreparationView(workspace: workspace, dataset: dataset).id(dataset.id)
            case .statistics: StatisticsView(workspace: workspace, dataset: dataset).id(dataset.id)
            case .visualization:
              VisualizationView(workspace: workspace, dataset: dataset).id(dataset.id)
            case .results: ResultsView(workspace: workspace)
            default: ProjectView(workspace: workspace)
            }
          } else {
            ContentUnavailableView(
              "Importa tu primer conjunto", systemImage: "tablecells",
              description: Text(
                "Crea o abre un proyecto e importa CSV, TSV o Parquet para empezar."))
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        Divider()
        HStack(spacing: 10) {
          if workspace.busy {
            ProgressView().controlSize(.small)
            Text(LocalizedStringKey(workspace.status))
            Spacer()
            Button("Cancelar", action: workspace.cancel)
          } else {
            Image(systemName: "internaldrive")
            Text(
              workspace.status.isEmpty
                ? "Procesamiento local · tus fuentes se conservan" : workspace.status)
            Spacer()
            Text("0.1 · desarrollo")
          }
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 35)
      }
      .toolbar {
        ToolbarItemGroup {
          Button(action: workspace.openProject) { Label("Abrir", systemImage: "folder") }.help(
            "Abrir proyecto · ⌘O")
          Button(action: workspace.chooseImport) {
            Label("Importar", systemImage: "square.and.arrow.down")
          }.disabled(workspace.project == nil || workspace.busy)
        }
      }
    }
    .navigationTitle(LocalizedStringKey(workspace.selectedSection?.rawValue ?? "VAPULA"))
    .sheet(isPresented: $workspace.showImport) {
      ImportView(workspace: workspace).interactiveDismissDisabled(workspace.busy)
    }
    .sheet(item: $workspace.evidenceFinding) { finding in
      VStack(alignment: .leading, spacing: 16) {
        Text(finding.rule.label).font(.title2)
        Text(
          "\(finding.affectedRows) filas candidatas; se muestran hasta 100. Una detección no confirma un error."
        ).foregroundStyle(.secondary)
        DataGrid(
          columns: workspace.project?.datasets.first { $0.id == finding.datasetID }?.columns ?? [],
          rows: workspace.evidencePage.rows)
        Button("Cerrar") { workspace.evidenceFinding = nil }.keyboardShortcut(.cancelAction)
      }.padding(24).frame(width: 850, height: 520)
    }
    .alert(
      "No se pudo completar la operación",
      isPresented: Binding(
        get: { workspace.error != nil }, set: { if $0 == false { workspace.error = nil } })
    ) {
      Button("Entendido") { workspace.error = nil }
    } message: {
      Text(workspace.error ?? "")
    }
    .dropDestination(for: URL.self) { urls, _ in
      guard let url = urls.first, workspace.project != nil, workspace.busy == false else {
        return false
      }
      workspace.prepareImport(url)
      return true
    }
  }
}
struct ProjectView: View {
  let workspace: Workspace
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        HStack(alignment: .center, spacing: 36) {
          SealView().frame(width: 140, height: 140)
          VStack(alignment: .leading, spacing: 12) {
            Text("VAPULA").font(.system(size: 44, weight: .medium)).tracking(5)
            Text("Data & Statistical Laboratory").font(.title2).foregroundStyle(.secondary)
            Text("De los datos a la evidencia.").font(.title3)
          }
        }
        Divider()
        Text("Un espacio para comprender tus datos").font(.title2.weight(.semibold))
        Text(
          "Importa, revisa la calidad y construye versiones reproducibles. Lleva la misma versión al laboratorio estadístico y conserva cada resultado junto a su procedencia."
        ).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        HStack {
          Button("Nuevo proyecto…", action: workspace.createProject).buttonStyle(.borderedProminent)
            .tint(.primary)
          Button("Abrir proyecto…", action: workspace.openProject)
        }.controlSize(.large).disabled(workspace.busy)
        if let project = workspace.project {
          VStack(alignment: .leading, spacing: 12) {
            Text(project.name).font(.title3.weight(.semibold))
            Text(
              "\(project.sources.count) fuentes · \(project.datasets.count) versiones · \(project.results.count) análisis"
            ).foregroundStyle(.secondary)
            Button("Importar datos…", action: workspace.chooseImport).disabled(workspace.busy)
            Button("Cerrar proyecto", action: workspace.closeProject).disabled(workspace.busy)
          }
          if project.datasets.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
              Text("Historial de versiones").font(.headline)
              ForEach(project.datasets) { v in
                HStack {
                  VStack(alignment: .leading) {
                    Text(v.operation?.summary ?? "Import: \(v.name)")
                    Text("\(v.rowCount) filas · \(v.id.uuidString.prefix(8))").font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Button("Usar versión") { workspace.selectVersion(v.id) }
                }
              }
            }
          }
        }
        Label(
          "Todo se procesa en tu Mac. Las fuentes originales se conservan.",
          systemImage: "lock.shield"
        ).font(.callout).foregroundStyle(.secondary)
      }.padding(44).frame(maxWidth: 900, alignment: .leading).frame(
        maxWidth: .infinity, alignment: .center)
    }
  }
}
struct SealView: View {
  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      Path { p in
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * side, y: y * side) }
        p.move(to: pt(0.2, 0.28))
        p.addLine(to: pt(0.2, 0.76))
        p.addLine(to: pt(0.8, 0.76))
        p.addLine(to: pt(0.8, 0.28))
        p.move(to: pt(0.2, 0.32))
        p.addLine(to: pt(0.36, 0.32))
        p.addLine(to: pt(0.36, 0.48))
        p.addLine(to: pt(0.64, 0.48))
        p.addLine(to: pt(0.64, 0.32))
        p.addLine(to: pt(0.8, 0.32))
        p.move(to: pt(0.5, 0.44))
        p.addLine(to: pt(0.5, 0.22))
        p.move(to: pt(0.5, 0.22))
        p.addCurve(to: pt(0.5, 0.12), control1: pt(0.30, 0.10), control2: pt(0.41, 0.03))
        p.addCurve(to: pt(0.5, 0.22), control1: pt(0.59, 0.03), control2: pt(0.70, 0.10))
        p.move(to: pt(0.5, 0.76))
        p.addLine(to: pt(0.5, 0.88))
        p.move(to: pt(0.4, 0.88))
        p.addLine(to: pt(0.6, 0.88))
      }.stroke(
        .primary,
        style: StrokeStyle(lineWidth: max(1.5, side * 0.022), lineCap: .round, lineJoin: .round))
    }.accessibilityHidden(true)
  }
}
