import SwiftUI
import VapulaCore

struct ContentView: View {
  @Bindable var workspace: Workspace
  var body: some View {
    VStack(spacing: 0) {
      WorkbenchHeader(workspace: workspace)
      Divider()
      if workspace.project == nil { ProjectView(workspace: workspace).frame(maxWidth: .infinity, maxHeight: .infinity) }
      else { WorkbenchView(workspace: workspace) }
      Divider()
      HStack(spacing: 7) {
        if workspace.busy { ProgressView().controlSize(.small) } else { Image(systemName: "internaldrive").foregroundStyle(.secondary) }
        Text(workspace.status.isEmpty ? "Procesamiento local · tus fuentes se conservan" : workspace.status).lineLimit(1)
        Spacer()
        if workspace.busy { Button("Cancelar", action: workspace.cancel).controlSize(.small) }
        else { Text(workspace.workflowUnsaved ? "Cambios del flujo por guardar" : "VAPULA · local").foregroundStyle(.secondary) }
      }.font(.system(size: 10.5)).padding(.horizontal, 16).frame(height: 30)
    }.tint(WorkbenchInk.accent)
      .sheet(isPresented: $workspace.showImport) { ImportView(workspace: workspace).interactiveDismissDisabled(workspace.busy) }
      .sheet(item: $workspace.editRequest) { request in DataEditingView(workspace: workspace, request: request).interactiveDismissDisabled(workspace.busy) }
      .sheet(item: $workspace.evidenceFinding) { finding in
        VStack(alignment: .leading, spacing: 16) {
          Text(finding.rule.label).font(.title2)
          Text("\(finding.affectedRows) filas candidatas · se muestran hasta 100. Una detección no confirma un error.").foregroundStyle(.secondary)
          DataGrid(columns: workspace.project?.datasets.first { $0.id == finding.datasetID }?.columns ?? [], rows: workspace.evidencePage.rows)
          Button("Cerrar") { workspace.evidenceFinding = nil }.keyboardShortcut(.cancelAction)
        }.padding(24).frame(width: 850, height: 520)
      }
      .alert("No se pudo completar la operación", isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) {
        Button("Entendido") { workspace.error = nil }
      } message: { Text(workspace.error ?? "") }
      .dropDestination(for: URL.self) { urls, _ in
        guard let url = urls.first, workspace.project != nil, !workspace.busy else { return false }
        workspace.prepareImport(url); return true
      }
  }
}
private struct WorkbenchView: View {
  @Bindable var workspace: Workspace
  @State private var expandedPreview = false
  var body: some View {
    HStack(spacing: 0) {
      if workspace.workflowSidebar { WorkbenchSidebar(workspace: workspace).frame(width: 158); Divider() }
      VStack(spacing: 0) {
        WorkbenchTools(workspace: workspace)
        Divider()
        WorkbenchCanvas(workspace: workspace).frame(maxWidth: .infinity, maxHeight: .infinity)
        if workspace.workflowPreview {
          Divider()
          WorkbenchPreview(workspace: workspace, expanded: $expandedPreview).frame(height: expandedPreview ? 370 : 240)
        }
      }.frame(minWidth: 530)
      if workspace.workflowInspector { Divider(); WorkbenchInspector(workspace: workspace).frame(width: 295) }
    }
  }
}
private struct WorkbenchHeader: View {
  @Bindable var workspace: Workspace
  var body: some View {
    HStack(spacing: 12) {
      Color.clear.frame(width: 66, height: 1)
      SealView().frame(width: 25, height: 25)
      Text("VAPULA").font(.system(size: 13, weight: .semibold)).tracking(1.7)
      Rectangle().fill(.quaternary).frame(width: 1, height: 18).padding(.horizontal, 4)
      Text(workspace.project?.name ?? "Data & Statistical Laboratory").font(.system(size: 12, weight: .medium)).lineLimit(1)
      Spacer(minLength: 15)
      if workspace.project != nil {
        Button(action: workspace.undoWorkflow) { Image(systemName: "arrow.uturn.backward") }.disabled(!workspace.workflowUndoAvailable || workspace.busy).help("Deshacer cambio del flujo")
        Button(action: workspace.persistWorkflow) { Image(systemName: "square.and.arrow.down") }.disabled(workspace.busy).help("Guardar el flujo")
      }
      Button(action: workspace.openProject) { Image(systemName: "folder") }.disabled(workspace.busy).help("Abrir proyecto · ⌘O")
      if workspace.project != nil {
        Rectangle().fill(.quaternary).frame(width: 1, height: 18).padding(.horizontal, 4)
        Button { workspace.workflowSidebar.toggle() } label: { Image(systemName: "sidebar.left") }.help("Biblioteca")
        Button { workspace.workflowPreview.toggle() } label: { Image(systemName: "rectangle.bottomthird.inset.filled") }.help("Vista previa")
        Button { workspace.workflowInspector.toggle() } label: { Image(systemName: "sidebar.right") }.help("Inspector")
      }
      SettingsLink { Image(systemName: "gearshape") }.help("Ajustes")
    }.buttonStyle(.borderless).font(.system(size: 13)).padding(.horizontal, 16).frame(height: 54).background(.bar)
  }
}
private struct WorkbenchSidebar: View {
  let workspace: Workspace
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Mi laboratorio").font(.system(size: 12, weight: .semibold)).padding(16).padding(.top, 5)
      Button { workspace.workflowTab = .data; workspace.workflowPreview = true } label: {
        Label("Flujo de trabajo", systemImage: "point.3.connected.trianglepath.dotted").font(.system(size: 11.5, weight: .medium))
          .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(WorkbenchInk.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
      }.buttonStyle(.plain).padding(.horizontal, 7)
      Button {
        workspace.workflowNodeID = nil; workspace.workflowTab = .result; workspace.workflowPreview = true
      } label: {
        Label("Resultados guardados", systemImage: "doc.text").font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }.buttonStyle(.plain).padding(.horizontal, 7)
      Divider().padding(.horizontal, 14).padding(.vertical, 17)
      Text("Fuentes").font(.system(size: 10.5, weight: .medium)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 8)
      ScrollView {
        VStack(alignment: .leading, spacing: 3) {
          ForEach(workspace.project?.sources ?? []) { source in
            Button {
              if let version = workspace.project?.datasets.first(where: { $0.sourceID == source.id && $0.parentID == nil }),
                let node = workspace.workflow.nodes.first(where: { $0.outputDatasetID == version.id }) { workspace.selectWorkflowNode(node.id) }
            } label: {
              Label(source.name, systemImage: "tablecells").font(.system(size: 11)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8).padding(.horizontal, 14)
            }.buttonStyle(.plain).help(source.name)
          }
        }
      }
      Menu("Historial") {
        ForEach((workspace.project?.datasets ?? []).reversed()) { version in
          Button("\(version.name) · \(version.operation?.displayTitle ?? "Original") · \(version.id.uuidString.prefix(6))") {
            workspace.showHistoricalVersion(version)
          }
        }
      }.font(.system(size: 10.5)).padding(.horizontal, 12).padding(.bottom, 16)
      VStack(alignment: .leading, spacing: 10) {
        Label("Todo en tu Mac", systemImage: "lock").font(.system(size: 10.5, weight: .medium))
        Text("Tus datos originales se conservan.").font(.system(size: 10.5)).foregroundStyle(.secondary)
        Divider()
        HStack {
          Text("Creado por\nSebastián Pastén F.").font(.system(size: 10)).foregroundStyle(.secondary)
          Spacer(minLength: 2)
          Link(destination: URL(string: "https://ko-fi.com/sebastianpasten")!) { Image(systemName: "cup.and.saucer") }.help("Apoyar el desarrollo")
        }
      }.padding(15)
    }.frame(maxHeight: .infinity).background(.background.secondary).disabled(workspace.busy)
  }
}
private struct WorkbenchTools: View {
  let workspace: Workspace
  var body: some View {
    HStack(spacing: 4) {
      ForEach(WorkflowKind.allCases, id: \.self) { kind in
        WorkbenchTool(kind: kind) { workspace.addWorkflowNode(kind) }
          .disabled(workspace.busy || (kind != .data && workspace.workflow.nodes.isEmpty))
      }
      Spacer(minLength: 5)
      Button { workspace.executeWorkflowNode() } label: {
        Label("Ejecutar", systemImage: "play.fill").font(.system(size: 11, weight: .semibold))
      }.buttonStyle(.borderedProminent).controlSize(.small).disabled(workspace.busy || workspace.workflow.nodes.isEmpty).help("Ejecutar pasos pendientes del flujo")
    }.padding(.horizontal, 10).frame(height: 65)
  }
}
private struct WorkbenchTool: View {
  let kind: WorkflowKind
  let action: () -> Void
  @State private var hovered = false
  var body: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: kind.symbol).font(.system(size: 17)).frame(height: 19)
        Text(kind == .missing ? "Ausentes" : kind == .data ? "Importar" : kind.title).font(.system(size: 10.5))
      }.frame(width: 53, height: 49).background(hovered ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
    }.buttonStyle(.plain).onHover { hovered = $0 }.help("Añadir \(kind.title.lowercased())")
  }
}
