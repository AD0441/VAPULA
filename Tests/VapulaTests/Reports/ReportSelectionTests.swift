import Foundation
import Testing
import VapulaCore
import VapulaReports

struct ReportSelectionTests {
  struct Fixture {
    var project = VapulaProject(name: "Selection")
    var graph = DataWorkflow()
    let resultID: UUID
    let reportID: UUID
    let analysisID: UUID
    init() {
      let a = DataSource(name: "selected.csv", bytes: 10, sha256: "selected-hash", format: "csv", options: ImportOptions())
      let b = DataSource(name: "unrelated.csv", bytes: 20, sha256: "unrelated-hash", format: "csv", options: ImportOptions())
      let va = DatasetVersion(name: "Selected data", sourceID: a.id)
      let vb = DatasetVersion(name: "Unrelated data", sourceID: b.id)
      let spec = AnalysisSpecification(method: .descriptive, x: "x")
      let ra = AnalysisResult(datasetID: va.id, specification: spec, validCount: 2, excludedCount: 0, metrics: ["mean": 10], warnings: [], procedure: "selected procedure")
      let rb = AnalysisResult(datasetID: vb.id, specification: spec, validCount: 2, excludedCount: 0, metrics: ["mean": 99], warnings: [], procedure: "unrelated procedure")
      let fa = QualityFinding(datasetID: va.id, rule: .missing("x"), affectedRows: 1)
      let fb = QualityFinding(datasetID: vb.id, rule: .missing("x"), affectedRows: 2)
      let sa = WorkflowNode(name: "A", task: .data(va.id), position: WorkflowPoint(0, 0))
      let sb = WorkflowNode(name: "B", task: .data(vb.id), position: WorkflowPoint(0, 100))
      var aa = WorkflowNode(name: "A stats", task: .analyze(spec), inputs: [sa.id], position: WorkflowPoint(100, 0))
      aa.dirty = false; aa.outputResultID = ra.id
      var ab = WorkflowNode(name: "B stats", task: .analyze(spec), inputs: [sb.id], position: WorkflowPoint(100, 100))
      ab.dirty = false; ab.outputResultID = rb.id
      var qa = WorkflowNode(name: "A quality", task: .quality([.missing("x")]), inputs: [sa.id], position: WorkflowPoint(100, 200))
      qa.dirty = false; qa.qualityFindings = [fa]
      var chart = WorkflowNode(name: "A chart", task: .chart(WorkflowChart(x: "x")), inputs: [sa.id], position: WorkflowPoint(100, 300))
      chart.dirty = false
      let pending = WorkflowNode(name: "B pending chart", task: .chart(WorkflowChart(x: "x")), inputs: [sb.id], position: WorkflowPoint(100, 400))
      var report = WorkflowNode(name: "Selected report", task: .report, inputs: [aa.id, qa.id, chart.id], position: WorkflowPoint(300, 0))
      report.dirty = false
      project.sources = [a, b]; project.datasets = [va, vb]; project.results = [ra, rb]; project.findings = [fa, fb]
      graph.nodes = [sa, sb, aa, ab, qa, chart, pending, report]
      resultID = ra.id; reportID = report.id; analysisID = aa.id
    }
  }
  @Test func reportBoxAndIndividualResultExcludeUnrelatedBranches() throws {
    let f = Fixture()
    let report = try ReportSelection.plan(project: f.project, workflow: f.graph, scope: .node(f.reportID))
    #expect(report.project.results.map(\.id) == [f.resultID])
    #expect(report.project.findings.count == 1 && report.charts.count == 1)
    #expect(report.project.sources.map(\.name) == ["selected.csv"])
    let individual = try ReportSelection.plan(project: f.project, workflow: f.graph, scope: .result(f.resultID))
    #expect(individual.project.findings.isEmpty && individual.charts.isEmpty)
    let markdown = Reports.markdown(individual.project)
    #expect(markdown.contains("selected procedure"))
    #expect(markdown.contains("unrelated") == false)
  }
  @Test func wholeProjectIncludesHistoryAndCountsChartsNotYetExecuted() throws {
    let f = Fixture()
    let plan = try ReportSelection.plan(project: f.project, workflow: f.graph, scope: .project)
    #expect(plan.project.results.count == 2 && plan.project.findings.count == 2)
    #expect(plan.charts.count == 1 && plan.omittedCharts == 1)
  }
  @Test func staleOrForeignSelectionsCannotBeExported() throws {
    var f = Fixture()
    let index = try #require(f.graph.nodes.firstIndex { $0.id == f.analysisID })
    f.graph.nodes[index].dirty = true
    #expect(throws: VapulaError.self) { try ReportSelection.plan(project: f.project, workflow: f.graph, scope: .node(f.reportID)) }
    #expect(throws: VapulaError.self) { try ReportSelection.plan(project: f.project, workflow: f.graph, scope: .result(UUID())) }
    #expect(throws: VapulaError.self) { try ReportSelection.plan(project: f.project, workflow: f.graph, scope: .node(UUID())) }
  }
}
