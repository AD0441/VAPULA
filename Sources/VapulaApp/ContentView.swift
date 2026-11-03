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
            Text(L("VAPULA")).font(.headline).tracking(2)
            Text(L("Data & Statistical Laboratory")).font(.caption2).foregroundStyle(.secondary)
          }
        }.padding(18)
        List(WorkspaceSection.allCases, selection: $workspace.selectedSection) { item in
          Label(T(item.rawValue), systemImage: item.symbol).tag(item)
        }.listStyle(.sidebar)
        VStack(alignment: .leading, spacing: 12) {
          if let project = workspace.project {
            Text(project.name).font(.subheadline.weight(.medium))
            Text(L("\(project.datasets.count) versiones · guardado automático")).font(.caption)
              .foregroundStyle(.secondary)
          }
          Divider()
          HStack {
            SettingsLink { Label(L("Ajustes"), systemImage: "gearshape") }
            Spacer()
            Link(destination: URL(string: "https://ko-fi.com/C0C51WQ1T0")!) {
              Image(systemName: "cup.and.saucer").accessibilityLabel(
                L("Apoyar en Ko-fi; abre el navegador"))
            }
          }
          Text(L("Creado por Sebastián Pastén F.")).font(.caption2).foregroundStyle(.secondary)
        }.buttonStyle(.plain).padding(18)
      }.navigationSplitViewColumnWidth(min: 235, ideal: 250, max: 300)
    } detail: {
      VStack(spacing: 0) {
        if let project = workspace.project, project.datasets.isEmpty == false {
          HStack {
            Text(L("Versión de datos")).foregroundStyle(.secondary)
            Picker(
              L("Versión de datos"),
              selection: Binding(get: { workspace.datasetID }, set: { workspace.selectVersion($0) })
            ) {
              ForEach(project.datasets) { v in
                Text(
                  L("\(v.name) · \(v.operation?.summary ?? "Import") · \(v.id.uuidString.prefix(6))")
                ).tag(Optional(v.id))
              }
            }.labelsHidden().frame(maxWidth: 620)
            Spacer()
            if let v = workspace.dataset {
              Text(L("\(v.rowCount) filas · \(v.columns.count) columnas")).font(.callout)
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
              L("Importa tu primer conjunto"), systemImage: "tablecells",
              description: Text(
                L("Crea o abre un proyecto e importa CSV, TSV o Parquet para empezar.")))
          }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        Divider()
        HStack(spacing: 10) {
          if workspace.busy {
            ProgressView().controlSize(.small)
            Text(T(workspace.status))
            Spacer()
            Button(L("Cancelar"), action: workspace.cancel)
          } else {
            Image(systemName: "internaldrive")
            Text(
              workspace.status.isEmpty
                ? "Procesamiento local · tus fuentes se conservan" : workspace.status)
            Spacer()
            Text(L("0.1 · desarrollo"))
          }
        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).frame(height: 35)
      }
      .toolbar {
        ToolbarItemGroup {
          Button(action: workspace.openProject) { Label(L("Abrir"), systemImage: "folder") }.help(
            L("Abrir proyecto · ⌘O"))
          Button(action: workspace.chooseImport) {
            Label(L("Importar"), systemImage: "square.and.arrow.down")
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
        Text(D(finding.rule.label)).font(.title2)
        Text(
          L("\(finding.affectedRows) filas candidatas; se muestran hasta 100. Una detección no confirma un error.")
        ).foregroundStyle(.secondary)
        DataGrid(
          columns: workspace.project?.datasets.first { $0.id == finding.datasetID }?.columns ?? [],
          rows: workspace.evidencePage.rows)
        Button(L("Cerrar")) { workspace.evidenceFinding = nil }.keyboardShortcut(.cancelAction)
      }.padding(24).frame(width: 850, height: 520)
    }
    .alert(
      L("No se pudo completar la operación"),
      isPresented: Binding(
        get: { workspace.error != nil }, set: { if $0 == false { workspace.error = nil } })
    ) {
      Button(L("Entendido")) { workspace.error = nil }
    } message: {
      Text(D(workspace.error ?? ""))
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
            Text(L("VAPULA")).font(.system(size: 44, weight: .medium)).tracking(5)
            Text(L("Data & Statistical Laboratory")).font(.title2).foregroundStyle(.secondary)
            Text(L("De los datos a la evidencia.")).font(.title3)
          }
        }
        Divider()
        Text(L("Un espacio para comprender tus datos")).font(.title2.weight(.semibold))
        Text(
          L("Importa, revisa la calidad y construye versiones reproducibles. Lleva la misma versión al laboratorio estadístico y conserva cada resultado junto a su procedencia.")
        ).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        HStack {
          Button(L("Nuevo proyecto…"), action: workspace.createProject).buttonStyle(.borderedProminent)
            .tint(.primary)
          Button(L("Abrir proyecto…"), action: workspace.openProject)
        }.controlSize(.large).disabled(workspace.busy)
        if let project = workspace.project {
          VStack(alignment: .leading, spacing: 12) {
            Text(project.name).font(.title3.weight(.semibold))
            Text(
              L("\(project.sources.count) fuentes · \(project.datasets.count) versiones · \(project.results.count) análisis")
            ).foregroundStyle(.secondary)
            Button(L("Importar datos…"), action: workspace.chooseImport).disabled(workspace.busy)
            Button(L("Cerrar proyecto"), action: workspace.closeProject).disabled(workspace.busy)
          }
          if project.datasets.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
              Text(L("Historial de versiones")).font(.headline)
              ForEach(project.datasets) { v in
                HStack {
                  VStack(alignment: .leading) {
                    Text(v.operation?.summary ?? "Import: \(v.name)")
                    Text(L("\(v.rowCount) filas · \(v.id.uuidString.prefix(8))")).font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Button(L("Usar versión")) { workspace.selectVersion(v.id) }
                }
              }
            }
          }
        }
        Label(
          L("Todo se procesa en tu Mac. Las fuentes originales se conservan."),
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
