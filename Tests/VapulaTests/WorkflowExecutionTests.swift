import Foundation
import Testing
import VapulaCore
import VapulaData

struct WorkflowExecutionTests {
  @Test func actualWorkflowRunsBothBranchesAndKeepsThePortableGraph() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-flow-\(UUID())")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let engine = DataEngine(); let package = dir.appendingPathComponent("real.vapula")
    _ = try await engine.create(at: package, name: "Flujo real")
    let csv = dir.appendingPathComponent("input.csv")
    try Data("id,x,y\n1,2,3\n2,4,5\n3,,7\n4,8,9\n".utf8).write(to: csv)
    let version = try await engine.importFile(csv, options: ImportOptions())
    let source = WorkflowNode(name: "CSV", task: .data(version.id), position: WorkflowPoint(100, 100))
    let fill = WorkflowNode(name: "Media", task: .prepare(.missing(columns: ["x"], action: .mean, policy: MissingPolicy())), inputs: [source.id], position: WorkflowPoint(335, 100))
    let analysis = WorkflowNode(name: "Descriptiva", task: .analyze(AnalysisSpecification(method: .descriptive, x: "x")), inputs: [fill.id], position: WorkflowPoint(570, 100))
    var style = ChartConfiguration(); style.binCount = 8
    let chart = WorkflowNode(name: "Histograma", task: .chart(WorkflowChart(x: "x", style: style)), inputs: [fill.id], position: WorkflowPoint(570, 300))
    let report = WorkflowNode(name: "Informe", task: .report, inputs: [analysis.id, chart.id], position: WorkflowPoint(805, 100))
    var workflow = DataWorkflow(); workflow.nodes = [source, fill, analysis, chart, report]
    let run = try await engine.executeWorkflow(workflow)
    let persisted = try #require(run.project.workflow)
    #expect(run.project.datasets.count == 2 && run.project.results.count == 1)
    #expect(persisted.nodes.allSatisfy { !$0.dirty && $0.lastError == nil })
    #expect(run.charts[chart.id]?.histogram.reduce(0) { $0 + $1.y } == 4)
    #expect(run.project.results[0].validCount == 4 && run.project.results[0].excludedCount == 0)
    #expect(run.project.results[0].warnings.contains { $0.contains("imputación") })
    #expect(try await engine.profile(datasetID: version.id).first { $0.column.name == "x" }?.missing == 1)
    await engine.close()
    let reopened = try await engine.open(at: package)
    #expect(reopened.workflow == persisted)
    var changed = persisted
    let index = try #require(changed.nodes.firstIndex { $0.id == fill.id })
    changed.nodes[index].task = .prepare(.missing(columns: ["x"], action: .constant("10"), policy: MissingPolicy()))
    changed.invalidate(fill.id)
    let rerun = try await engine.executeWorkflow(changed, through: analysis.id)
    #expect(rerun.project.datasets.count == 3 && rerun.project.results.count == 2)
    #expect(rerun.project.workflow?.nodes.first { $0.id == chart.id }?.dirty == true)
    #expect(rerun.project.workflow?.nodes.first { $0.id == report.id }?.dirty == true)
    #expect(rerun.project.results.last?.metrics["mean"] == 6)
    await engine.close()
  }
  @Test func graphValidationRejectsCyclesAndWrongKinds() throws {
    let dataID = UUID()
    let source = WorkflowNode(name: "Datos", task: .data(dataID), position: WorkflowPoint(100, 100))
    let a = WorkflowNode(name: "A", task: .prepare(nil), inputs: [source.id], position: WorkflowPoint(335, 100))
    let b = WorkflowNode(name: "B", task: .prepare(nil), inputs: [a.id], position: WorkflowPoint(570, 100))
    var graph = DataWorkflow(); graph.nodes = [source, a, b]
    graph.nodes[1].inputs = [b.id]
    #expect(throws: VapulaError.self) { try graph.validate(datasetIDs: [dataID], resultIDs: []) }
    graph.nodes[1].inputs = [source.id]; graph.nodes[1].task = .analyze(nil)
    #expect(throws: VapulaError.self) { try graph.validate(datasetIDs: [dataID], resultIDs: []) }
  }
  @Test func sourceIdentityMustMatchItsDeclaredOutput() throws {
    let id = UUID(), other = UUID()
    var graph = DataWorkflow()
    var node = WorkflowNode(name: "Fuente", task: .data(id), position: WorkflowPoint(1, 1))
    node.outputDatasetID = other; graph.nodes = [node]
    #expect(throws: VapulaError.self) { try graph.validate(datasetIDs: [id, other], resultIDs: []) }
  }
  @Test func oldProjectsAcquireAProvenanceGraphWithoutRewritingTables() {
    var project = VapulaProject(name: "Anterior")
    let first = DatasetVersion(name: "Original", sourceID: UUID())
    let second = DatasetVersion(name: "Filtrada", sourceID: first.sourceID, parentID: first.id, operation: .filter(column: "x", comparison: .greater, value: "0"))
    project.datasets = [first, second]
    let graph = DataWorkflow.inferred(from: project)
    #expect(graph.nodes.count == 2)
    #expect(graph.nodes[1].inputs == [graph.nodes[0].id])
    #expect(graph.nodes[1].outputDatasetID == second.id)
    #expect(graph.nodes.allSatisfy { !$0.dirty })
    #expect(project.workflow == nil)
  }
}
