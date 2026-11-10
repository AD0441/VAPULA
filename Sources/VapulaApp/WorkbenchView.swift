import SwiftUI
import VapulaCore

struct ContentView: View {
  @Bindable var workspace: Workspace
  var body: some View {
    VStack(spacing: 0) {
      WorkbenchHeader(workspace: workspace)
      Divider()
      if let notice = workspace.recoveryNotice {
        VStack(alignment: .leading, spacing: 7) {
          HStack {
            Label(T(notice.interrupted ? "Sesión interrumpida: proyecto verificado" : "Proyecto verificado: datos adicionales conservados"), systemImage: "checkmark.shield").font(.headline)
            Spacer()
            Button(L("Entendido")) { workspace.recoveryNotice = nil }
          }
          Text(L("Se verificaron \(notice.verifiedVersions) versiones guardadas. Puedes continuar desde el último paso completo."))
          if notice.unreferencedTables > 0 {
            Text(L("Hay \(notice.unreferencedTables) tablas sin referencia en el historial. Se conservan en el paquete; no se borró información para recuperar el proyecto."))
          }
          Text(L("Cierra el proyecto antes de copiar el paquete como respaldo.")).foregroundStyle(.secondary)
        }.font(.callout).padding(14).background(.quaternary.opacity(0.35))
        Divider()
      }
      if workspace.project == nil { ProjectView(workspace: workspace).frame(maxWidth: .infinity, maxHeight: .infinity) }
      else { WorkbenchView(workspace: workspace) }
      Divider()
      HStack(spacing: 7) {
        if workspace.busy { ProgressView().controlSize(.small) } else { Image(systemName: "internaldrive").foregroundStyle(.secondary) }
        Text(workspace.status.isEmpty ? T("Procesamiento local · tus fuentes se conservan") : D(workspace.status)).lineLimit(1)
        Spacer()
        if workspace.busy { Button(L("Cancelar"), action: workspace.cancel).controlSize(.small) }
        else { Text(!workspace.inspectorDrafts.isEmpty ? L("Borradores sin ejecutar: \(workspace.inspectorDrafts.count)") : workspace.workflowUnsaved ? T("Cambios del flujo por guardar") : "VAPULA · local").foregroundStyle(.secondary) }
      }.font(.system(size: 10.5)).padding(.horizontal, 16).frame(height: 30)
    }.tint(WorkbenchInk.accent)
      .sheet(isPresented: $workspace.showImport) { ImportView(workspace: workspace).interactiveDismissDisabled(workspace.busy) }
      .sheet(item: $workspace.reportExportRequest, onDismiss: {
        Task { await workspace.chooseReportDestination() }
      }) { request in
        ReportExportView(workspace: workspace, request: request)
      }
      .sheet(item: $workspace.editRequest) { request in DataEditingView(workspace: workspace, request: request).interactiveDismissDisabled(workspace.busy) }
      .sheet(item: $workspace.evidenceFinding) { finding in
        VStack(alignment: .leading, spacing: 16) {
          Text(D(finding.rule.label)).font(.title2)
          Text(L("\(finding.affectedRows) filas candidatas · se muestran hasta 100. Una detección no confirma un error.")).foregroundStyle(.secondary)
          DataGrid(columns: workspace.project?.datasets.first { $0.id == finding.datasetID }?.columns ?? [], rows: workspace.evidencePage.rows)
          Button(L("Cerrar")) { workspace.evidenceFinding = nil }.keyboardShortcut(.cancelAction)
        }.padding(24).frame(width: 850, height: 520)
      }
      .alert(L("No se pudo completar la operación"), isPresented: Binding(get: { workspace.error != nil }, set: { if !$0 { workspace.error = nil } })) {
        Button(L("Entendido")) { workspace.error = nil }
      } message: { Text(D(workspace.error ?? "")) }
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
    GeometryReader { geometry in
    HStack(spacing: 0) {
      if workspace.workflowSidebar { WorkbenchSidebar(workspace: workspace).frame(width: 180); Divider() }
      VStack(spacing: 0) {
        WorkbenchTools(workspace: workspace)
        Divider()
        WorkbenchCanvas(workspace: workspace).frame(maxWidth: .infinity, maxHeight: .infinity)
        if workspace.workflowPreview {
          Divider()
          WorkbenchPreview(workspace: workspace, expanded: $expandedPreview)
            .frame(height: min(expandedPreview ? 370 : 240, geometry.size.height * (expandedPreview ? 0.48 : 0.36)))
        }
      }.frame(minWidth: 480)
      if workspace.workflowInspector { Divider(); WorkbenchInspector(workspace: workspace).frame(width: 320) }
    }
    }
  }
}
private struct WorkbenchHeader: View {
  @Bindable var workspace: Workspace
  var body: some View {
    HStack(spacing: 12) {
      Color.clear.frame(width: 66, height: 1)
      SealView().frame(width: 25, height: 25)
      Text(L("VAPULA")).font(.system(size: 13, weight: .semibold)).tracking(1.7)
      Rectangle().fill(.quaternary).frame(width: 1, height: 18).padding(.horizontal, 4)
      Text(workspace.project?.name ?? "Data & Statistical Laboratory").font(.system(size: 12, weight: .medium)).lineLimit(1)
      Spacer(minLength: 15)
      if workspace.project != nil {
        Button(action: workspace.undoWorkflow) { Image(systemName: "arrow.uturn.backward") }.disabled(!workspace.workflowUndoAvailable || workspace.busy).help(L("Deshacer cambio del flujo")).accessibilityLabel(L("Deshacer cambio del flujo"))
        Button(action: workspace.persistWorkflow) { Image(systemName: "square.and.arrow.down") }.disabled(workspace.busy).help(L("Guardar el flujo")).accessibilityLabel(L("Guardar el flujo"))
      }
      Button(action: workspace.openProject) { Image(systemName: "folder") }.disabled(workspace.busy).help(L("Abrir proyecto · ⌘O")).accessibilityLabel(L("Abrir proyecto"))
      if workspace.project != nil {
        Rectangle().fill(.quaternary).frame(width: 1, height: 18).padding(.horizontal, 4)
        Button { workspace.workflowSidebar.toggle() } label: { Image(systemName: "sidebar.left") }.help(L("Biblioteca")).accessibilityLabel(L("Biblioteca")).accessibilityValue(T(workspace.workflowSidebar ? "Visible" : "Oculta"))
        Button { workspace.workflowPreview.toggle() } label: { Image(systemName: "rectangle.bottomthird.inset.filled") }.help(L("Vista previa")).accessibilityLabel(L("Vista previa")).accessibilityValue(T(workspace.workflowPreview ? "Visible" : "Oculta"))
        Button { workspace.workflowInspector.toggle() } label: { Image(systemName: "sidebar.right") }.help(L("Inspector")).accessibilityLabel(L("Inspector")).accessibilityValue(T(workspace.workflowInspector ? "Visible" : "Oculto"))
      }
      SettingsLink { Image(systemName: "gearshape") }.help(L("Ajustes")).accessibilityLabel(L("Ajustes"))
    }.buttonStyle(.borderless).font(.system(size: 13)).padding(.horizontal, 16).frame(height: 54).background(.bar)
  }
}
private struct WorkbenchSidebar: View {
  let workspace: Workspace
  @FocusState private var stepsFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(L("Mi laboratorio")).font(.system(size: 12, weight: .semibold)).padding(16).padding(.top, 5)
      Button { workspace.workflowTab = .data; workspace.workflowPreview = true } label: {
        Label(L("Flujo de trabajo"), systemImage: "point.3.connected.trianglepath.dotted").font(.system(size: 11.5, weight: .medium))
          .frame(maxWidth: .infinity, alignment: .leading).padding(10).background(WorkbenchInk.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 6))
      }.buttonStyle(.plain).padding(.horizontal, 7).disabled(workspace.busy)
      Button {
        workspace.workflowNodeID = nil; workspace.workflowTab = .result; workspace.workflowPreview = true
      } label: {
        Label(L("Resultados guardados"), systemImage: "doc.text").font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }.buttonStyle(.plain).padding(.horizontal, 7).disabled(workspace.busy)
      ScrollViewReader { proxy in
      List(selection: Binding<UUID?>(get: { workspace.workflowNodeID }, set: { if let id = $0 { workspace.selectWorkflowNode(id) } })) {
        Section(L("Pasos del flujo")) {
          ForEach(workspace.workflow.nodes) { node in
            Label {
              VStack(alignment: .leading, spacing: 3) {
                Text(node.displayName).lineLimit(2)
                Text(T(node.lastError != nil ? "Revisar" : !node.task.configured ? "Configurar" : node.dirty ? "Por ejecutar" : "Listo"))
                  .font(.caption2).foregroundStyle(.secondary)
              }
            } icon: { Image(systemName: node.kind.symbol).foregroundStyle(node.kind.ink) }
              .tag(node.id).id(node.id).help(node.name)
          }
        }
        Section(L("Fuentes")) {
          ForEach(workspace.project?.sources ?? []) { source in
            Button {
              if let version = workspace.project?.datasets.first(where: { $0.sourceID == source.id && $0.parentID == nil }),
                let node = workspace.workflow.nodes.first(where: { $0.outputDatasetID == version.id }) { workspace.selectWorkflowNode(node.id) }
            } label: { Label(source.name, systemImage: "tablecells").lineLimit(2) }
              .buttonStyle(.plain).help(source.name)
          }
        }
      }.listStyle(.sidebar).font(.system(size: 11.5)).accessibilityLabel(L("Pasos y fuentes del flujo"))
        .focused($stepsFocused)
        .task(id: workspace.workflowStepsFocusRequested) {
          guard workspace.workflowStepsFocusRequested else { return }
          await Task.yield()
          guard !Task.isCancelled else { return }
          stepsFocused = true
          workspace.workflowStepsFocusRequested = false
        }
        .onChange(of: workspace.workflowNodeID) { _, id in
          if let id { proxy.scrollTo(id, anchor: .center) }
        }
        .onAppear { if let id = workspace.workflowNodeID { proxy.scrollTo(id, anchor: .center) } }
      }
      Menu(L("Historial")) {
        ForEach((workspace.project?.datasets ?? []).reversed()) { version in
          Button(L("\(version.name) · \(version.operation?.displayTitle ?? "Original") · \(version.id.uuidString.prefix(6))")) {
            workspace.showHistoricalVersion(version)
          }
        }
      }.font(.system(size: 10.5)).padding(.horizontal, 12).padding(.bottom, 16).disabled(workspace.busy)
      VStack(alignment: .leading, spacing: 10) {
        Label(L("Todo en tu Mac"), systemImage: "lock").font(.system(size: 10.5, weight: .medium))
        Text(L("Tus datos originales se conservan.")).font(.system(size: 10.5)).foregroundStyle(.secondary)
        Divider()
        HStack {
          Text(L("Creado por\nSebastián Pastén F.")).font(.system(size: 10)).foregroundStyle(.secondary)
          Spacer(minLength: 2)
          Link(destination: URL(string: "https://ko-fi.com/C0C51WQ1T0")!) { Image(systemName: "cup.and.saucer") }.help(L("Apoyar el desarrollo")).accessibilityLabel(L("Apoyar en Ko-fi; abre el navegador"))
        }
      }.padding(15)
    }.frame(maxHeight: .infinity).background(.background.secondary)
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
        Label(L("Ejecutar"), systemImage: "play.fill").font(.system(size: 11, weight: .semibold))
      }.buttonStyle(.borderedProminent).controlSize(.small).disabled(workspace.busy || workspace.workflow.nodes.isEmpty).help(L("Ejecutar pasos pendientes del flujo"))
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
        Text(T(kind == .missing ? "Ausentes" : kind == .data ? "Importar" : kind.title)).font(.system(size: 10.5))
      }.frame(width: 53, height: 49).background(hovered ? Color.primary.opacity(0.045) : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
    }.buttonStyle(.plain).onHover { hovered = $0 }.help(L("Añadir \(T(kind.title).lowercased())"))
  }
}
