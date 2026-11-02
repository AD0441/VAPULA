import Foundation
import Testing
import VapulaCore
import VapulaData

struct CastPreviewTests {
  @Test func previewCountsOnlyNewNullsAndRequiresMatchingApproval() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-cast-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("in.csv")
    // A second column keeps the deliberately empty value as a real CSV row.
    let csv = "id,x\n1,1\n2,no\n3,\n4,bad\n5,NaN\n"
    try Data(csv.utf8).write(to: input)
    let engine = DataEngine()
    _ = try await engine.create(at: root.appendingPathComponent("p.vapula"), name: "Cast")
    var options = ImportOptions(); options.allText = true
    let version = try await engine.importFile(input, options: options)
    let impact = try await engine.castImpact(datasetID: version.id, column: "x", type: .number)
    #expect(impact.newNulls == 2 && impact.existingNulls == 1)
    #expect(Set(impact.examples) == ["no", "bad"])
    #expect(try await engine.snapshot().datasets.count == 1)
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: version.id, operation: .cast(column: "x", type: .number))
    }
    let wrong = CastApproval(datasetID: version.id, column: "x", type: .number, newNulls: 1)
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: version.id, operation: .cast(column: "x", type: .number), castApproval: wrong)
    }
    let converted = try await engine.transform(datasetID: version.id, operation: .cast(column: "x", type: .number), castApproval: impact.approval)
    #expect(converted.parentID == version.id)
    let profile = try await engine.profile(datasetID: converted.id)
    #expect(profile.first { $0.column.name == "x" }?.missing == 4) // NULLs plus preserved NaN.
    let copy = try await engine.transform(datasetID: version.id, operation: .sort(column: "id", ascending: false))
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: copy.id, operation: .cast(column: "x", type: .number), castApproval: impact.approval)
    }
    #expect(try String(contentsOf: input, encoding: .utf8) == csv)
    await engine.close()
  }

  @Test func workflowCannotReuseApprovalAfterUpstreamVersionChanges() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-cast-flow-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("in.csv")
    try Data("x\n1\nbad\n".utf8).write(to: input)
    let engine = DataEngine(); _ = try await engine.create(at: root.appendingPathComponent("p.vapula"), name: "Flow")
    var options = ImportOptions(); options.allText = true
    let version = try await engine.importFile(input, options: options)
    let source = WorkflowNode(name: "Source", task: .data(version.id), position: WorkflowPoint(0, 0))
    var cast = WorkflowNode(name: "Cast", task: .prepare(.cast(column: "x", type: .number)), inputs: [source.id], position: WorkflowPoint(100, 0))
    var graph = DataWorkflow(); graph.nodes = [source, cast]
    await #expect(throws: VapulaError.self) { try await engine.executeWorkflow(graph) }
    #expect(try await engine.snapshot().datasets.count == 1)
    cast.castApproval = try await engine.castImpact(datasetID: version.id, column: "x", type: .number).approval
    graph.nodes[1] = cast
    let executed = try await engine.executeWorkflow(graph)
    #expect(executed.project.datasets.count == 2)
    let next = try await engine.transform(datasetID: version.id, operation: .sort(column: "x", ascending: true))
    var changed = try #require(executed.project.workflow)
    changed.nodes[0].task = .data(next.id); changed.nodes[0].outputDatasetID = next.id
    changed.invalidate(cast.id)
    await #expect(throws: VapulaError.self) { try await engine.executeWorkflow(changed, through: cast.id) }
    #expect(try await engine.snapshot().datasets.count == 3)
    await engine.close()
  }
}
