import SwiftUI
import VapulaCore

struct WorkbenchInspector: View {
  @Bindable var workspace: Workspace
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(L("Inspector")).font(.system(size: 12, weight: .semibold)); Spacer()
        Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary).accessibilityHidden(true)
      }.padding(17).frame(height: 48)
      Divider()
      if let node = workspace.workflowNode {
        VStack(alignment: .leading, spacing: 10) {
          Label(T(node.kind.title), systemImage: node.kind.symbol).font(.system(size: 11)).foregroundStyle(node.kind.ink)
          Text(node.displayName).font(.system(size: 17, weight: .semibold)).lineLimit(3).help(node.name).fixedSize(horizontal: false, vertical: true)
          HStack(spacing: 5) {
            Image(systemName: node.lastError != nil ? "exclamationmark.circle" : node.dirty ? "circle.dashed" : "checkmark.circle.fill")
            Text(T(node.lastError != nil ? "Revisa la configuración" : !node.task.configured ? "Por configurar" : node.dirty ? "Por ejecutar" : "Resultado disponible"))
          }.font(.system(size: 10.5)).foregroundStyle(node.dirty ? WorkbenchInk.warning : WorkbenchInk.accent)
          ForEach(node.inputs, id: \.self) { input in
            if let parent = workspace.workflow.nodes.first(where: { $0.id == input }) {
              Button { workspace.selectWorkflowNode(input) } label: {
                Label(parent.displayName, systemImage: parent.kind.symbol).font(.system(size: 11)).lineLimit(1)
              }.buttonStyle(.plain).help(L("Inspeccionar entrada"))
            }
          }
          if node.kind != .data && node.kind != .report {
            Menu(L("Cambiar entrada…")) {
              ForEach(workspace.workflow.connectionCandidates(to: node.id)) { candidate in
                Button(candidate.displayName) {
                  workspace.workflowConnection = candidate.id
                  workspace.connectWorkflow(to: node.id)
                }
              }
            }.font(.caption).disabled(workspace.busy)
              .help(L("Elige una caja compatible sin arrastrar conexiones"))
          }
          if let error = node.lastError { Text(D(error)).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
          if let key = workspace.draftKey(nodeID: node.id, datasetID: node.kind == .report ? nil : workspace.workflowInput(node)?.id), workspace.inspectorDrafts[key] != nil {
            Label(L("Borrador conservado · sin ejecutar"), systemImage: "pencil.circle").font(.caption).foregroundStyle(.secondary)
            Button(L("Descartar este borrador")) { workspace.discardDraft(for: key) }.font(.caption).disabled(workspace.busy)
          }
        }.padding(16)
        Divider()
        InspectorBody(workspace: workspace, node: node).id("\(node.id)-\(workspace.workflowInput(node)?.id.uuidString ?? "")-\(workspace.inspectorRevision)")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        Divider()
        HStack {
          Text(L("Cada cambio conserva su entrada")).font(.system(size: 9.5)).foregroundStyle(.secondary)
          Spacer(minLength: 4)
          Button { workspace.removeWorkflowBranch(node.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain).help(L("Retirar la rama del flujo; sus datos guardados se conservan")).accessibilityLabel(L("Retirar rama"))
        }.padding(15).disabled(workspace.busy)
      } else {
        ContentUnavailableView(L("Selecciona una caja"), systemImage: "cursorarrow", description: Text(L("Sus opciones y resultados aparecerán aquí.")))
      }
    }.background(.background)
  }
}
private struct InspectorBody: View {
  let workspace: Workspace
  let node: WorkflowNode
  var body: some View {
    if case .data = node.task, let version = workspace.workflowPreviewVersion(node) {
      SourceInspector(workspace: workspace, version: version)
    } else if node.kind == .report {
      ReportInspector(workspace: workspace, node: node)
    } else if let version = workspace.workflowInput(node) {
      switch node.task {
      case .prepare(let operation):
        if case .missing = operation {
          MissingValuesView(workspace: workspace, dataset: version, draftKey: workspace.draftKey(nodeID: node.id, datasetID: version.id), initial: operation) {
            workspace.updateAndRunWorkflowNode(node.id, task: .prepare($0))
          }
        } else if manual(operation) {
          ScrollView {
            VStack(alignment: .leading, spacing: 15) {
              Text(operation?.summary ?? "Edición de datos").font(.callout)
              Text(L("La corrección pertenece a esta versión. Puedes continuar editando desde la tabla; cada cambio creará una versión nueva.")).font(.caption).foregroundStyle(.secondary)
              Button(L("Volver a ejecutar este paso")) { workspace.executeWorkflowNode(node.id) }
            }.padding(16)
          }
        } else {
          PreparationView(workspace: workspace, dataset: version, draftKey: workspace.draftKey(nodeID: node.id, datasetID: version.id), initial: operation,
            onApply: { operation, approval in workspace.updateAndRunWorkflowNode(node.id, task: .prepare(operation), castApproval: approval) },
            compact: true, purpose: .transform)
        }
      case .quality(let rules):
        PreparationView(workspace: workspace, dataset: version, draftKey: workspace.draftKey(nodeID: node.id, datasetID: version.id),
          onAudit: { workspace.updateAndRunWorkflowNode(node.id, task: .quality($0)) },
          compact: true, purpose: .quality, initialRules: rules)
      case .analyze(let specification):
        StatisticsView(workspace: workspace, dataset: version, draftKey: workspace.draftKey(nodeID: node.id, datasetID: version.id), initial: specification,
          onCalculate: { workspace.updateAndRunWorkflowNode(node.id, task: .analyze($0)) }, compact: true)
      case .chart(let chart):
        WorkbenchChartInspector(workspace: workspace, node: node, dataset: version, initial: chart)
      default: EmptyView()
      }
    } else {
      VStack(alignment: .leading, spacing: 15) {
        Text(L("La entrada todavía no está disponible.")).font(.headline)
        Text(L("Ejecuta el paso anterior para obtener su versión de datos y poder configurar esta caja.")).font(.callout).foregroundStyle(.secondary)
        if let input = node.inputs.first {
          Button(L("Ejecutar entrada")) { workspace.executeWorkflowNode(input) }.buttonStyle(.borderedProminent)
        }
      }.padding(16).frame(maxHeight: .infinity, alignment: .top)
    }
  }
  private func manual(_ operation: Transformation?) -> Bool {
    switch operation { case .addColumn, .appendRow, .editCell, .removeRows: true; default: false }
  }
}
private struct SourceInspector: View {
  let workspace: Workspace
  let version: DatasetVersion
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 17) {
        Text(L("Versión de datos")).font(.headline)
        Text(L("\(version.rowCount) filas · \(version.columns.count) columnas")).font(.callout).monospacedDigit()
        if let source = workspace.project?.sources.first(where: { $0.id == version.sourceID }) {
          Text(source.name).font(.callout).textSelection(.enabled)
          Text(L("\(source.format.uppercased()) · fuente incorporada al proyecto")).font(.caption).foregroundStyle(.secondary)
          DisclosureGroup(L("Procedencia")) {
            Text(L("SHA-256: \(source.sha256)")).font(.caption).textSelection(.enabled).padding(.top, 7)
          }
        }
        Divider()
        Button(L("Calcular perfil completo"), action: workspace.profile)
        ForEach(workspace.profiles) { profile in
          DisclosureGroup(profile.column.name) {
            VStack(alignment: .leading, spacing: 6) {
              Text(L("\(profile.valid) válidos · \(profile.missing) ausentes/no finitos"))
              Text(L("\(profile.distinct) valores distintos"))
              if let mean = profile.mean { Text(L("Media: \(mean.formatted(.number.precision(.significantDigits(6))))")) }
              if let median = profile.median { Text(L("Mediana: \(median.formatted(.number.precision(.significantDigits(6))))")) }
              Text(L("Min: \(profile.minimum ?? "—") · Max: \(profile.maximum ?? "—")"))
            }.font(.caption).padding(.top, 8).textSelection(.enabled)
          }.font(.system(size: 12))
        }
        Divider()
        Text(L("Añade un paso desde la barra o el botón + de esta caja. También puedes corregir una celda con doble clic en la tabla.")).font(.caption).foregroundStyle(.secondary)
      }.padding(16)
    }.disabled(workspace.busy)
  }
}
private struct WorkbenchChartInspector: View {
  let workspace: Workspace
  let node: WorkflowNode
  let dataset: DatasetVersion
  @State private var request: WorkflowChart
  @State private var baseline: WorkflowChart
  let draftRevision: Int
  private var draftKey: InspectorDraftKey? { workspace.draftKey(nodeID: node.id, datasetID: dataset.id) }
  init(workspace: Workspace, node: WorkflowNode, dataset: DatasetVersion, initial: WorkflowChart?) {
    self.workspace = workspace; self.node = node; self.dataset = dataset; self.draftRevision = workspace.inspectorRevision
    var value = initial ?? WorkflowChart(x: dataset.columns.first(where: \.isNumeric)?.name ?? dataset.columns.first?.name ?? "")
    if !dataset.columns.contains(where: { $0.name == value.x }) { value.x = dataset.columns.first(where: \.isNumeric)?.name ?? dataset.columns.first?.name ?? "" }
    _baseline = State(initialValue: value)
    if let key = workspace.draftKey(nodeID: node.id, datasetID: dataset.id), case .chart(let draft) = workspace.inspectorDrafts[key] { value = draft }
    _request = State(initialValue: value)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      VStack(alignment: .leading, spacing: 10) {
        Picker(L("Tipo"), selection: $request.style.kind) { ForEach(ChartKind.allCases) { Text(T($0.title)).tag($0) } }
        Picker(L("X"), selection: $request.x) { ForEach(dataset.columns) { Text($0.name).tag($0.name) } }
        if [.scatter, .line, .area].contains(request.style.kind) {
          Picker(L("Y"), selection: $request.y) {
            Text(L("Elegir variable")).tag("")
            ForEach(dataset.columns.filter(\.isNumeric)) { Text($0.name).tag($0.name) }
          }
        }
        Button(L("Actualizar gráfico")) { apply() }.buttonStyle(.borderedProminent).disabled(!request.style.hasValidColor)
        Text(L("Las opciones se aplican al actualizar este paso.")).font(.caption).foregroundStyle(.secondary)
      }.font(.system(size: 12)).padding(.horizontal, 16).padding(.top, 14)
      Divider()
      ChartStylePanel(configuration: $request.style, isBusy: workspace.busy, save: apply,
        saveTitle: "Aplicar y actualizar gráfico").padding(.trailing, 15)
    }.disabled(workspace.busy)
      .onChange(of: request) { cacheDraft() }
      .onDisappear { cacheDraft() }
  }
  private func cacheDraft() {
    guard draftRevision == workspace.inspectorRevision else { return }
    workspace.recordDraft(request == baseline ? nil : .chart(request), for: draftKey)
  }
  private func apply() {
    guard request.style.hasValidColor else {
      workspace.error = L("Escribe un color HEX válido antes de actualizar el gráfico, por ejemplo #256A8A.")
      return
    }
    baseline = request; workspace.recordDraft(nil, for: draftKey)
    workspace.updateAndRunWorkflowNode(node.id, task: .chart(request))
  }
}
private struct ReportInspector: View {
  let workspace: Workspace
  let node: WorkflowNode
  @State private var inputs = Set<UUID>()
  @State private var baseline: Set<UUID>?
  @State private var draftRevision = -1
  private var draftKey: InspectorDraftKey? { workspace.draftKey(nodeID: node.id, datasetID: nil) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 17) {
        Text(L("Qué salidas incluir")).font(.headline)
        Text(L("Reúne resultados, gráficos y controles de calidad del proyecto.")).font(.caption).foregroundStyle(.secondary)
        ForEach(workspace.workflow.nodes.filter { [.analyze, .chart, .quality].contains($0.kind) }) { item in
          Toggle(isOn: Binding(get: { inputs.contains(item.id) }, set: { if $0 { inputs.insert(item.id) } else { inputs.remove(item.id) } })) {
            Label(item.displayName, systemImage: item.kind.symbol).font(.system(size: 12)).lineLimit(2)
          }.toggleStyle(.checkbox)
        }
        Button(L("Actualizar informe")) {
          guard let index = workspace.workflow.nodes.firstIndex(where: { $0.id == node.id }) else { return }
          workspace.rememberWorkflow()
          workspace.workflow.nodes[index].inputs = workspace.workflow.nodes.filter { inputs.contains($0.id) }.map(\.id)
          baseline = inputs; workspace.recordDraft(nil, for: draftKey)
          workspace.inspectorRevision += 1
          workspace.workflow.invalidate(node.id); workspace.executeWorkflowNode(node.id)
        }.buttonStyle(.borderedProminent).disabled(inputs.isEmpty)
        Text(L("Los pasos que ya están listos se conservan. Se ejecutan las entradas que necesiten actualizarse.")).font(.caption).foregroundStyle(.secondary)
      }.padding(16)
    }.disabled(workspace.busy).onAppear {
      draftRevision = workspace.inspectorRevision
      inputs = Set(node.inputs); baseline = inputs
      if let draftKey, case .report(let draft) = workspace.inspectorDrafts[draftKey] { inputs = draft }
    }
      .onChange(of: inputs) { cacheDraft() }
      .onDisappear { cacheDraft() }
  }
  private func cacheDraft() {
    guard let baseline, draftRevision == workspace.inspectorRevision else { return }
    workspace.recordDraft(inputs == baseline ? nil : .report(inputs), for: draftKey)
  }
}
