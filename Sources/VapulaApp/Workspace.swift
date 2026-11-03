import AppKit
import Observation
import UniformTypeIdentifiers
import VapulaCore
import VapulaData
import VapulaReports

@Observable
final class Workspace {
  var project: VapulaProject?
  var projectURL: URL?
  var datasetID: UUID?
  var page = DataPage(rows: [], matchingRows: 0)
  var profiles: [ColumnProfile] = []
  var offset = 0
  var search = ""
  private var activeSearch = ""
  var sortColumn: String?
  var ascending = true
  var busy = false
  var status = L("")
  var error: String?
  var reportExportRequest: ReportExportRequest?
  var recoveryNotice: ProjectRecoveryNotice?
  var inspectorDrafts = InspectorDraftStore()
  var inspectorRevision = 0
  var selectedSection: WorkspaceSection? = .projects
  var importURL: URL?
  var showImport = false
  var previewColumns: [ColumnDefinition] = []
  var previewRows: [DataRow] = []
  var previewError: String?
  var evidenceFinding: QualityFinding?
  var evidencePage = DataPage(rows: [], matchingRows: 0)
  var histogram: [ChartPoint] = []
  var scatter: [ChartPoint] = []
  var frequencies: [Frequency] = []
  var chartProfile: ColumnProfile?
  var chartDescription = ""
  var chartX = ""
  var chartY = ""
  var chartBinCount = 20
  var chartConfiguration = ChartConfiguration()
  var boxSummary: BoxSummary?
  var workflow = DataWorkflow()
  var workflowNodeID: UUID?
  var workflowCharts: [UUID: WorkflowChartOutput] = [:]
  var workflowFitRequest = 0
  var workflowFocusID: UUID?
  var workflowConnection: UUID?
  var workflowInspector = true
  var workflowSidebar = true
  var workflowPreview = true
  var workflowTab = WorkbenchTab.data
  var workflowUndoAvailable = false
  var workflowUnsaved = false
  var selectedDataRows: [DataRow] = []
  var editRequest: DataEditRequest?
  @ObservationIgnored var workflowHistory: [DataWorkflow] = []
  @ObservationIgnored let engine = DataEngine()
  @ObservationIgnored private var task: Task<Void, Never>?
  var dataset: DatasetVersion? { project?.datasets.first { $0.id == datasetID } }
  var findings: [QualityFinding] { project?.findings.filter { $0.datasetID == datasetID } ?? [] }
  func run(_ label: String, operation: @escaping @MainActor () async throws -> Void) {
    guard busy == false else { return }
    busy = true
    status = label
    error = nil
    task = Task {
      defer {
        busy = false
        task = nil
      }
      do {
        try await operation()
        status = L("Listo")
      } catch is CancellationError {
        status = L("Cancelado; no se guardó el trabajo incompleto")
      } catch {
        self.error = error.localizedDescription
        status = L("Revisa el error y vuelve a intentar")
      }
    }
  }
  func cancel() {
    task?.cancel()
    status = L("Cancelando al finalizar la consulta actual…")
  }
  func createProject() {
    guard busy == false else { return }
    let panel = NSSavePanel()
    panel.title = L("Crear proyecto VAPULA")
    panel.nameFieldStringValue = L("Sin título.vapula")
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    let target = url.pathExtension == "vapula" ? url : url.appendingPathExtension("vapula")
    guard confirmDiscardDrafts() else { return }
    run(L("Creando proyecto…")) {
      try await self.savePendingWorkflow()
      let p = try await self.engine.create(
        at: target, name: target.deletingPathExtension().lastPathComponent)
      self.reset(p, url: target)
    }
  }
  func openProject() {
    guard busy == false else { return }
    let panel = NSOpenPanel()
    panel.title = L("Abrir proyecto .vapula")
    panel.treatsFilePackagesAsDirectories = false
    panel.allowedContentTypes = [
      UTType(exportedAs: "cl.sebastianpasten.vapula-project", conformingTo: .package), .folder,
    ]
    // macOS 27 recomputes selection flags when package/type options change.
    // Set explicit file/directory choices last, also preserving older systems.
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    guard panel.runModal() == .OK, let url = panel.url else { return }
    openProject(at: url)
  }
  func openProject(at url: URL) {
    if projectURL?.resolvingSymlinksInPath().standardizedFileURL == url.resolvingSymlinksInPath().standardizedFileURL { return }
    guard !busy, confirmDiscardDrafts() else { return }
    run(L("Abriendo proyecto…")) {
      try await self.savePendingWorkflow()
      let p = try await self.engine.open(at: url)
      self.reset(p, url: url)
      self.recoveryNotice = await self.engine.recoveryNotice
      try await self.refresh()
    }
  }
  func reset(_ p: VapulaProject, url: URL) {
    project = p
    recoveryNotice = nil; reportExportRequest = nil
    inspectorDrafts.removeAll(); inspectorRevision += 1
    projectURL = url
    datasetID = p.datasets.last?.id
    resetDataPresentation()
    workflow = p.workflow ?? DataWorkflow.inferred(from: p)
    workflowNodeID = workflow.nodes.last { $0.outputDatasetID == datasetID }?.id ?? workflow.nodes.first?.id
    workflowCharts = [:]; workflowHistory = []; workflowUndoAvailable = false
    workflowUnsaved = false; workflowTab = .data; selectedDataRows = []
    workflowFitRequest += 1
    selectedSection = .workflow
  }
  func resetDataPresentation() {
    offset = 0
    search = ""
    activeSearch = ""
    sortColumn = nil
    ascending = true
    page = DataPage(rows: [], matchingRows: 0)
    profiles = []
    histogram = []
    scatter = []
    frequencies = []
    chartProfile = nil
    boxSummary = nil
    chartDescription = ""
    chartX = ""
    chartY = ""
    chartBinCount = 20
    chartConfiguration =
      datasetID.flatMap { project?.chartConfigurations?[$0.uuidString] } ?? ChartConfiguration()
    evidenceFinding = nil
    selectedDataRows = []
  }
  func closeProject() {
    guard !busy, confirmDiscardDrafts() else { return }
    run(L("Cerrando…")) {
      try await self.savePendingWorkflow()
      await self.engine.close()
      self.project = nil
      self.recoveryNotice = nil; self.inspectorDrafts.removeAll()
      self.projectURL = nil
      self.datasetID = nil
      self.page = DataPage(rows: [], matchingRows: 0)
      self.profiles = []
      self.selectedSection = .projects
      self.workflow = DataWorkflow(); self.workflowNodeID = nil; self.workflowCharts = [:]
    }
  }
  func selectVersion(_ id: UUID?) {
    guard busy == false else { return }
    datasetID = id
    resetDataPresentation()
    run(L("Cargando versión…")) { try await self.refresh() }
  }
  func refresh() async throws {
    guard let datasetID else { return }
    let result = try await engine.page(
      datasetID: datasetID, offset: offset, search: activeSearch, sort: sortColumn,
      ascending: ascending)
    try Task.checkCancellation()
    page = result
    project = try await engine.snapshot()
  }
  func reloadPage() {
    run(L("Consultando datos…")) {
      self.offset = 0
      self.activeSearch = self.search
      try await self.refresh()
    }
  }
  func turnPage(_ delta: Int) {
    run(L("Cargando página…")) {
      self.offset = max(0, self.offset + delta * 100)
      try await self.refresh()
    }
  }
  func sort(_ name: String) {
    guard busy == false else { return }
    if sortColumn == name {
      ascending.toggle()
    } else {
      sortColumn = name
      ascending = true
    }
    reloadPage()
  }
  func chooseImport() {
    guard project != nil, busy == false else { return }
    let panel = NSOpenPanel()
    panel.title = L("Importar CSV, TSV o Parquet")
    panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .data]
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    prepareImport(url)
  }
  func prepareImport(_ url: URL) {
    guard project != nil, busy == false else { return }
    importURL = url
    previewColumns = []
    previewRows = []
    previewError = nil
    showImport = true
  }
  func previewImport(_ options: ImportOptions) {
    guard let importURL else { return }
    run(L("Leyendo vista previa…")) {
      do {
        let preview = try await self.engine.preview(importURL, options: options)
        self.previewColumns = preview.columns
        self.previewRows = preview.rows
        self.previewError = nil
      } catch {
        self.previewError = error.localizedDescription
        self.previewRows = []
        self.previewColumns = []
      }
    }
  }
  func confirmImport(_ options: ImportOptions) {
    guard let importURL else { return }
    run(L("Importando y calculando SHA-256…")) {
      let v = try await self.engine.importFile(importURL, options: options)
      self.project = try await self.engine.snapshot()
      self.datasetID = v.id
      self.resetDataPresentation()
      self.showImport = false
      self.selectedSection = .data
      let node = WorkflowNode(name: v.name, task: .data(v.id), position: self.workflow.insertionPosition(after: nil))
      self.workflow.nodes.append(node); self.workflowNodeID = node.id
      try await self.engine.saveWorkflow(self.workflow)
      self.project = try await self.engine.snapshot()
      self.workflowTab = .data; self.workflowFocusID = node.id
      try await self.refresh()
    }
  }
  func profile() {
    guard let datasetID else { return }
    run(L("Calculando perfil completo…")) {
      self.profiles = try await self.engine.profile(datasetID: datasetID)
    }
  }
  func audit(keys: [String], rangeColumn: String?, lower: Double?, upper: Double?) {
    guard let dataset else { return }
    run(L("Revisando calidad…")) {
      var rules = dataset.columns.map { QualityRule.missing($0.name) }
      for col in dataset.columns where col.isNumeric {
        rules.append(.nonFinite(col.name))
        rules.append(.outlier(col.name))
      }
      if keys.isEmpty == false { rules.append(.duplicates(keys)) }
      if let rangeColumn, let lower, let upper { rules.append(.range(rangeColumn, lower, upper)) }
      _ = try await self.engine.audit(datasetID: dataset.id, rules: rules)
      self.project = try await self.engine.snapshot()
    }
  }
  func showEvidence(_ finding: QualityFinding) {
    run(L("Buscando evidencias…")) {
      self.evidencePage = try await self.engine.evidence(finding)
      self.evidenceFinding = finding
    }
  }
  func transform(_ operation: Transformation, castApproval: CastApproval? = nil) {
    guard let datasetID else { return }
    run(L("Creando versión…")) {
      let v = try await self.engine.transform(datasetID: datasetID, operation: operation, castApproval: castApproval)
      self.project = try await self.engine.snapshot()
      self.datasetID = v.id
      self.resetDataPresentation()
      try await self.refresh()
    }
  }
  func analyze(_ specification: AnalysisSpecification) {
    guard let datasetID else { return }
    run(L("Calculando análisis…")) {
      _ = try await self.engine.analyze(datasetID: datasetID, specification: specification)
      self.project = try await self.engine.snapshot()
      self.selectedSection = .results
    }
  }
  func charts(x: String, y: String) {
    guard let datasetID else { return }
    run(L("Preparando gráficos…")) {
      let configuration = self.chartConfiguration.normalized()
      let profile = try await self.engine.profile(datasetID: datasetID).first {
        $0.column.name == x
      }
      self.chartProfile = profile
      self.frequencies = try await self.engine.frequencies(datasetID: datasetID, column: x)
      if profile?.column.isNumeric == true {
        self.histogram = try await self.engine.histogram(
          datasetID: datasetID, column: x, bins: configuration.binCount)
        self.boxSummary = try await self.engine.boxplot(datasetID: datasetID, column: x)
      } else {
        self.histogram = []
        self.boxSummary = nil
      }
      if x.isEmpty == false, y.isEmpty == false {
        self.scatter = try await self.engine.scatter(datasetID: datasetID, x: x, y: y)
      } else {
        self.scatter = []
      }
      self.chartX = x
      self.chartY = y
      self.chartBinCount = configuration.binCount
      self.chartDescription = "X: \(x) · Y: \(y) · \(datasetID)"
    }
  }
  func exportData(parquet: Bool) {
    guard let datasetID else { return }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = parquet ? "datos.parquet" : "datos.csv"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    run(L("Exportando datos…")) {
      try await self.engine.exportData(datasetID: datasetID, to: url, parquet: parquet)
    }
  }
  func persistChartConfiguration() {
    guard let datasetID else { return }
    let configuration = chartConfiguration.normalized()
    run(L("Guardando estilo del gráfico…")) {
      try await self.engine.saveChartConfiguration(
        datasetID: datasetID, configuration: configuration)
      self.chartConfiguration = configuration
      self.project = try await self.engine.snapshot()
    }
  }
  func exportReport(csv: Bool) { requestReportExport(scope: .project, format: csv ? .csv : .markdown) }
  func exportReport(format: ReportExportFormat, result: AnalysisResult? = nil) {
    requestReportExport(scope: result.map { .result($0.id) } ?? .project, format: format)
  }
  func useVersion(_ id: UUID, section: WorkspaceSection) {
    selectVersion(id)
    selectedSection = section
  }
}
enum ReportExportFormat: Hashable {
  case pdf, markdown, csv
  var fileExtension: String {
    switch self {
    case .pdf: ".pdf"
    case .markdown: ".md"
    case .csv: ".csv"
    }
  }
}
enum WorkspaceSection: String, CaseIterable, Identifiable {
  case projects = "Proyectos"
  case workflow = "Flujo"
  case data = "Datos"
  case preparation = "Preparación"
  case statistics = "Estadística"
  case visualization = "Visualización"
  case results = "Resultados"
  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .projects: "folder"
    case .workflow: "point.3.connected.trianglepath.dotted"
    case .data: "tablecells"
    case .preparation: "slider.horizontal.3"
    case .statistics: "function"
    case .visualization: "chart.xyaxis.line"
    case .results: "doc.text"
    }
  }
}
