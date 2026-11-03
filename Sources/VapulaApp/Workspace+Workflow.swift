import Foundation
import VapulaCore
import VapulaData

enum WorkbenchTab: String, CaseIterable, Identifiable {
  case data = "Datos", result = "Resultado", chart = "Gráfico", report = "Informe"
  var id: String { rawValue }
}
extension Workspace {
  func savePendingWorkflow() async throws {
    guard project != nil, workflowUnsaved else { return }
    try await engine.saveWorkflow(workflow)
    project = try await engine.snapshot(); workflowUnsaved = false
  }
  func showHistoricalVersion(_ version: DatasetVersion) {
    guard !busy else { return }
    if let node = workflow.nodes.first(where: { $0.outputDatasetID == version.id }) { selectWorkflowNode(node.id); return }
    guard workflow.nodes.count < 500 else { error = L("Este flujo admite hasta 500 cajas."); return }
    rememberWorkflow()
    let node = WorkflowNode(name: version.name, task: .data(version.id), position: workflow.insertionPosition(after: nil))
    workflow.nodes.append(node); workflowNodeID = node.id; workflowFocusID = node.id
    persistWorkflow()
  }
  var workflowNode: WorkflowNode? { workflow.nodes.first { $0.id == workflowNodeID } }
  func selectAdjacentStep(_ delta: Int) {
    guard !busy, !workflow.nodes.isEmpty else { return }
    let index = workflow.nodes.firstIndex(where: { $0.id == workflowNodeID }) ?? (delta > 0 ? -1 : workflow.nodes.count)
    selectWorkflowNode(workflow.nodes[min(workflow.nodes.count - 1, max(0, index + delta))].id)
  }
  func workflowInput(_ node: WorkflowNode) -> DatasetVersion? {
    guard let id = node.inputs.first, let parent = workflow.nodes.first(where: { $0.id == id }),
      let versionID = parent.outputDatasetID else { return nil }
    return project?.datasets.first { $0.id == versionID }
  }
  func workflowPreviewVersion(_ node: WorkflowNode) -> DatasetVersion? {
    if let id = node.outputDatasetID, let v = project?.datasets.first(where: { $0.id == id }) { return v }
    var pending = node.inputs; var visited = Set<UUID>()
    while !pending.isEmpty {
      let id = pending.removeFirst()
      guard visited.insert(id).inserted, let parent = workflow.nodes.first(where: { $0.id == id }) else { continue }
      if let versionID = parent.outputDatasetID, let value = project?.datasets.first(where: { $0.id == versionID }) { return value }
      pending.append(contentsOf: parent.inputs)
    }
    return nil
  }
  func rememberWorkflow() {
    workflowUnsaved = true
    workflowHistory.append(workflow)
    if workflowHistory.count > 60 { workflowHistory.removeFirst() }
    workflowUndoAvailable = true
  }
  func persistWorkflow() {
    guard project != nil, !busy else { workflowUnsaved = true; return }
    if let node = workflowNode, let version = workflowPreviewVersion(node), datasetID != version.id {
      datasetID = version.id; resetDataPresentation()
    }
    let document = workflow
    run(L("Guardando flujo…")) {
      try await self.engine.saveWorkflow(document)
      self.project = try await self.engine.snapshot(); self.workflowUnsaved = false
      if self.datasetID != nil { try await self.refresh() }
    }
  }
  func undoWorkflow() {
    guard !busy, let previous = workflowHistory.popLast() else { return }
    workflow = previous; workflowUndoAvailable = !workflowHistory.isEmpty
    inspectorRevision += 1
    workflowNodeID = workflow.nodes.last?.id; persistWorkflow()
    workflowFitRequest += 1
  }
  func selectWorkflowNode(_ id: UUID) {
    guard !busy, let node = workflow.nodes.first(where: { $0.id == id }) else { return }
    workflowNodeID = id; workflowFocusID = id
    switch node.kind {
    case .analyze, .quality: workflowTab = .result
    case .chart: workflowTab = .chart
    case .report: workflowTab = .report
    default: workflowTab = .data
    }
    if let version = workflowPreviewVersion(node), datasetID != version.id {
      datasetID = version.id; resetDataPresentation()
      run(L("Cargando vista previa…")) { try await self.refresh() }
    }
  }
  func addWorkflowNode(_ kind: WorkflowKind, after parentID: UUID? = nil) {
    guard !busy, let project else { return }
    if kind == .data { chooseImport(); return }
    guard workflow.nodes.count < 500 else { error = L("Este flujo admite hasta 500 cajas."); return }
    let explicit = parentID.flatMap { id in workflow.nodes.first { $0.id == id } }
    let parent = (explicit ?? workflowNode).flatMap { $0.kind.compatibleNext.contains(kind) ? $0 : nil }
      ?? workflow.nodes.last { $0.kind.compatibleNext.contains(kind) }
    guard let parent else { error = kind == .report ? "Selecciona un análisis, gráfico o control de calidad." : "Importa una fuente de datos para comenzar."; return }
    let version = parent.outputDatasetID.flatMap { id in project.datasets.first { $0.id == id } }
    let task: WorkflowTask
    switch kind {
    case .prepare: task = .prepare(nil)
    case .missing:
      let column = version?.columns.first { $0.isNumeric && $0.name.lowercased() != "id" } ?? version?.columns.first
      task = .prepare(.missing(columns: column.map { [$0.name] } ?? [], action: column?.isNumeric == true ? .mean : .mode, policy: MissingPolicy()))
    case .quality: task = .quality(nil)
    case .analyze: task = .analyze(nil)
    case .chart:
      let x = version?.columns.first(where: { $0.isNumeric && $0.name.lowercased() != "id" })?.name ?? version?.columns.first(where: \.isNumeric)?.name ?? version?.columns.first?.name ?? ""
      let style = version.flatMap { project.chartConfigurations?[$0.id.uuidString] } ?? ChartConfiguration()
      task = .chart(WorkflowChart(x: x, style: style))
    case .report: task = .report
    case .data: return
    }
    rememberWorkflow()
    let node = WorkflowNode(name: kind.title, task: task, inputs: [parent.id], position: workflow.insertionPosition(after: parent))
    workflow.nodes.append(node); workflowNodeID = node.id; workflowFocusID = node.id
    workflowTab = kind == .chart ? .chart : kind == .report ? .report : .data
    persistWorkflow()
  }
  func updateAndRunWorkflowNode(_ id: UUID, task: WorkflowTask, castApproval: CastApproval? = nil) {
    guard !busy, let index = workflow.nodes.firstIndex(where: { $0.id == id }) else { return }
    rememberWorkflow(); workflow.nodes[index].task = task
    inspectorRevision += 1
    workflow.nodes[index].castApproval = castApproval
    switch task {
    case .prepare(let operation): workflow.nodes[index].name = operation?.displayTitle ?? "Preparar"
    case .analyze(let spec): workflow.nodes[index].name = spec?.method.title ?? "Analizar"
    case .chart(let chart): workflow.nodes[index].name = chart?.style.title.isEmpty == false ? chart!.style.title : "Gráfico"
    default: break
    }
    workflow.invalidate(id); workflowNodeID = id; executeWorkflowNode(id)
  }
  func executeWorkflowNode(_ id: UUID? = nil) {
    guard !busy, project != nil else { return }
    let order = (try? workflow.executionOrder(through: id)) ?? []
    let pending = workflow.nodes.filter { node in
      order.contains(node.id) && draftKey(nodeID: node.id, datasetID: node.kind == .report ? nil : workflowInput(node)?.id)
        .map { inspectorDrafts[$0] != nil } == true
    }
    guard pending.isEmpty else {
      error = L("Hay cambios sin aplicar en «\(pending[0].name)». Abre su inspector y aplícalos, o descarta ese borrador, antes de ejecutar esta rama.")
      return
    }
    if let id { workflowNodeID = id }
    let document = workflow
    run(id == nil ? "Ejecutando los pasos pendientes…" : "Ejecutando paso y entradas…") {
      do {
        let result = try await self.engine.executeWorkflow(document, through: id)
        self.project = result.project
        self.workflow = result.project.workflow ?? document
        self.workflowCharts.merge(result.charts) { _, new in new }
        self.workflowUnsaved = false
      } catch {
        if let snapshot = try? await self.engine.snapshot() {
          self.project = snapshot; self.workflow = snapshot.workflow ?? document
          if let failed = self.workflow.nodes.first(where: { $0.lastError != nil }) { self.workflowNodeID = failed.id }
        }
        throw error
      }
      if let node = self.workflowNode {
        if let version = self.workflowPreviewVersion(node) {
          self.datasetID = version.id; self.resetDataPresentation(); try await self.refresh()
        }
        switch node.kind {
        case .analyze, .quality: self.workflowTab = .result
        case .chart: self.workflowTab = .chart
        case .report: self.workflowTab = .report
        default: self.workflowTab = .data
        }
      }
    }
  }
  func connectWorkflow(to id: UUID) {
    guard !busy, let source = workflowConnection, let index = workflow.nodes.firstIndex(where: { $0.id == id }), let project else { return }
    workflowConnection = nil; var proposed = workflow
    if proposed.nodes[index].kind == .report {
      if proposed.nodes[index].inputs.contains(source) { return }
      proposed.nodes[index].inputs.append(source)
    } else {
      guard proposed.nodes[index].inputs != [source] else { return }
      proposed.nodes[index].inputs = [source]
    }
    do {
      try proposed.validate(datasetIDs: Set(project.datasets.map(\.id)), resultIDs: Set(project.results.map(\.id)))
      rememberWorkflow(); proposed.invalidate(id); workflow = proposed
      workflowNodeID = id; persistWorkflow()
    } catch { self.error = error.localizedDescription }
  }
  func moveWorkflowNode(_ id: UUID, x: Double, y: Double) {
    guard !busy, x.isFinite, y.isFinite, let i = workflow.nodes.firstIndex(where: { $0.id == id }) else { return }
    workflow.nodes[i].position = WorkflowPoint(min(90_000, max(-90_000, x)), min(90_000, max(-90_000, y)))
    workflowUnsaved = true
  }
  func removeWorkflowBranch(_ id: UUID) {
    guard !busy else { return }; rememberWorkflow()
    let branch = workflow.descendants(of: id)
    workflow.nodes.removeAll { branch.contains($0.id) }
    for id in branch { workflowCharts[id] = nil }
    workflowNodeID = workflow.nodes.last?.id; persistWorkflow()
  }
  func applyDataEdit(_ operation: Transformation, datasetID: UUID) {
    guard !busy else { return }
    var parent = workflow.nodes.last { $0.kind.suppliesData && $0.outputDatasetID == datasetID && !$0.dirty }
    rememberWorkflow()
    if parent == nil, let version = project?.datasets.first(where: { $0.id == datasetID }) {
      let source = WorkflowNode(name: version.name, task: .data(datasetID), position: workflow.insertionPosition(after: nil))
      workflow.nodes.append(source); parent = source
    }
    guard let parent else { error = L("No se encuentra la versión de datos."); return }
    let node = WorkflowNode(name: operation.displayTitle, task: .prepare(operation), inputs: [parent.id], position: workflow.insertionPosition(after: parent))
    workflow.nodes.append(node); workflowNodeID = node.id; workflowFocusID = node.id
    editRequest = nil; executeWorkflowNode(node.id)
  }
  func workflowResultIDs(_ node: WorkflowNode) -> Set<UUID> {
    let order = (try? workflow.executionOrder(through: node.id)) ?? []
    return Set(workflow.nodes.filter { order.contains($0.id) }.compactMap(\.outputResultID))
  }
}
