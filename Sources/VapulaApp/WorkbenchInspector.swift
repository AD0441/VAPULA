import SwiftUI
import VapulaCore

struct WorkbenchInspector: View {
  @Bindable var workspace: Workspace
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Inspector").font(.system(size: 12, weight: .semibold)); Spacer()
        Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
      }.padding(17).frame(height: 48)
      Divider()
      if let node = workspace.workflowNode {
        VStack(alignment: .leading, spacing: 10) {
          Label(node.kind.title, systemImage: node.kind.symbol).font(.system(size: 11)).foregroundStyle(node.kind.ink)
          Text(node.name).font(.system(size: 17, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
          HStack(spacing: 5) {
            Image(systemName: node.lastError != nil ? "exclamationmark.circle" : node.dirty ? "circle.dashed" : "checkmark.circle.fill")
            Text(node.lastError != nil ? "Revisa la configuración" : !node.task.configured ? "Por configurar" : node.dirty ? "Por ejecutar" : "Resultado disponible")
          }.font(.system(size: 10.5)).foregroundStyle(node.dirty ? WorkbenchInk.warning : WorkbenchInk.accent)
          ForEach(node.inputs, id: \.self) { input in
            if let parent = workspace.workflow.nodes.first(where: { $0.id == input }) {
              Button { workspace.selectWorkflowNode(input) } label: {
                Label(parent.name, systemImage: parent.kind.symbol).font(.system(size: 11)).lineLimit(1)
              }.buttonStyle(.plain).help("Inspeccionar entrada")
            }
          }
          if let error = node.lastError { Text(error).font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
          if let key = workspace.draftKey(nodeID: node.id, datasetID: node.kind == .report ? nil : workspace.workflowInput(node)?.id), workspace.inspectorDrafts[key] != nil {
            Label("Borrador conservado · sin ejecutar", systemImage: "pencil.circle").font(.caption).foregroundStyle(.secondary)
            Button("Descartar este borrador") { workspace.discardDraft(for: key) }.font(.caption).disabled(workspace.busy)
          }
        }.padding(16)
        Divider()
        InspectorBody(workspace: workspace, node: node).id("\(node.id)-\(workspace.workflowInput(node)?.id.uuidString ?? "")-\(workspace.inspectorRevision)")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        Divider()
        HStack {
          Text("Cada cambio conserva su entrada").font(.system(size: 9.5)).foregroundStyle(.secondary)
          Spacer(minLength: 4)
          Button { workspace.removeWorkflowBranch(node.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("Retirar la rama del flujo; sus datos guardados se conservan")
        }.padding(15).disabled(workspace.busy)
      } else {
        ContentUnavailableView("Selecciona una caja", systemImage: "cursorarrow", description: Text("Sus opciones y resultados aparecerán aquí."))
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
              Text("La corrección pertenece a esta versión. Puedes continuar editando desde la tabla; cada cambio creará una versión nueva.").font(.caption).foregroundStyle(.secondary)
              Button("Volver a ejecutar este paso") { workspace.executeWorkflowNode(node.id) }
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
        Text("La entrada todavía no está disponible.").font(.headline)
        Text("Ejecuta el paso anterior para obtener su versión de datos y poder configurar esta caja.").font(.callout).foregroundStyle(.secondary)
        if let input = node.inputs.first {
          Button("Ejecutar entrada") { workspace.executeWorkflowNode(input) }.buttonStyle(.borderedProminent)
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
        Text("Versión de datos").font(.headline)
        Text("\(version.rowCount) filas · \(version.columns.count) columnas").font(.callout).monospacedDigit()
        if let source = workspace.project?.sources.first(where: { $0.id == version.sourceID }) {
          Text(source.name).font(.callout).textSelection(.enabled)
          Text("\(source.format.uppercased()) · fuente incorporada al proyecto").font(.caption).foregroundStyle(.secondary)
          DisclosureGroup("Procedencia") {
            Text("SHA-256: \(source.sha256)").font(.caption).textSelection(.enabled).padding(.top, 7)
          }
        }
        Divider()
        Button("Calcular perfil completo", action: workspace.profile)
        ForEach(workspace.profiles) { profile in
          DisclosureGroup(profile.column.name) {
            VStack(alignment: .leading, spacing: 6) {
              Text("\(profile.valid) válidos · \(profile.missing) ausentes/no finitos")
              Text("\(profile.distinct) valores distintos")
              if let mean = profile.mean { Text("Media: \(mean.formatted(.number.precision(.significantDigits(6))))") }
              if let median = profile.median { Text("Mediana: \(median.formatted(.number.precision(.significantDigits(6))))") }
              Text("Min: \(profile.minimum ?? "—") · Max: \(profile.maximum ?? "—")")
            }.font(.caption).padding(.top, 8).textSelection(.enabled)
          }.font(.system(size: 12))
        }
        Divider()
        Text("Añade un paso desde la barra o el botón + de esta caja. También puedes corregir una celda con doble clic en la tabla.").font(.caption).foregroundStyle(.secondary)
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
        Picker("Tipo", selection: $request.style.kind) { ForEach(ChartKind.allCases) { Text($0.title).tag($0) } }
        Picker("X", selection: $request.x) { ForEach(dataset.columns) { Text($0.name).tag($0.name) } }
        if [.scatter, .line, .area].contains(request.style.kind) {
          Picker("Y", selection: $request.y) {
            Text("Elegir variable").tag("")
            ForEach(dataset.columns.filter(\.isNumeric)) { Text($0.name).tag($0.name) }
          }
        }
        Button("Actualizar gráfico") { apply() }.buttonStyle(.borderedProminent)
        Text("Las opciones se aplican al actualizar este paso.").font(.caption).foregroundStyle(.secondary)
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
        Text("Qué salidas incluir").font(.headline)
        Text("Reúne resultados, gráficos y controles de calidad del proyecto.").font(.caption).foregroundStyle(.secondary)
        ForEach(workspace.workflow.nodes.filter { [.analyze, .chart, .quality].contains($0.kind) }) { item in
          Toggle(isOn: Binding(get: { inputs.contains(item.id) }, set: { if $0 { inputs.insert(item.id) } else { inputs.remove(item.id) } })) {
            Label(item.name, systemImage: item.kind.symbol).font(.system(size: 12)).lineLimit(2)
          }.toggleStyle(.checkbox)
        }
        Button("Actualizar informe") {
          guard let index = workspace.workflow.nodes.firstIndex(where: { $0.id == node.id }) else { return }
          workspace.rememberWorkflow()
          workspace.workflow.nodes[index].inputs = workspace.workflow.nodes.filter { inputs.contains($0.id) }.map(\.id)
          baseline = inputs; workspace.recordDraft(nil, for: draftKey)
          workspace.inspectorRevision += 1
          workspace.workflow.invalidate(node.id); workspace.executeWorkflowNode(node.id)
        }.buttonStyle(.borderedProminent).disabled(inputs.isEmpty)
        Text("Los pasos que ya están listos se conservan. Se ejecutan las entradas que necesiten actualizarse.").font(.caption).foregroundStyle(.secondary)
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
