import Foundation
import Testing
import VapulaCore
import VapulaData
import VapulaReports

struct ProjectDataTests {
  func temporary() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
      "vapula-tests-\(UUID())")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }
  @Test func endToEndPortableProjectKeepsOriginalAndResults() async throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    let input = dir.appendingPathComponent("source's.csv")
    let original = "id,group,x,y\n1,A,1,3\n2,A,2,5\n3,B,3,7\n4,B,4,9\n4,B,4,9\n5,A,,11\n"
    try Data(original.utf8).write(to: input)
    let engine = DataEngine()
    let url = dir.appendingPathComponent("test.vapula")
    _ = try await engine.create(at: url, name: "Synthetic")
    let v = try await engine.importFile(input, options: ImportOptions())
    #expect(v.rowCount == 6)
    let page = try await engine.page(datasetID: v.id, limit: 2)
    #expect(page.rows.count == 2)
    #expect(page.matchingRows == 6)
    let profile = try await engine.profile(datasetID: v.id)
    let x = try #require(profile.first { $0.column.name == "x" })
    #expect(x.valid == 5)
    #expect(x.missing == 1)
    let findings = try await engine.audit(
      datasetID: v.id,
      rules: [.missing("x"), .duplicates(["id"]), .range("x", 0, 3), .outlier("x")])
    #expect(findings[0].affectedRows == 1)
    #expect(findings[1].affectedRows == 2)
    #expect(findings[2].affectedRows == 2)
    let evidence = try await engine.evidence(findings[1])
    #expect(evidence.rows.count == 2)
    let filtered = try await engine.transform(
      datasetID: v.id, operation: .filter(column: "x", comparison: .greater, value: "2"))
    #expect(filtered.rowCount == 3)
    #expect(filtered.parentID == v.id)
    let result = try await engine.analyze(
      datasetID: v.id, specification: AnalysisSpecification(method: .regression, x: "x", y: "y"))
    #expect(result.validCount == 5)
    #expect(result.excludedCount == 1)
    #expect(close(result.metrics["slope"] ?? 0, 2))
    let parquet = dir.appendingPathComponent("export.parquet")
    try await engine.exportData(datasetID: filtered.id, to: parquet, parquet: true)
    let copy = try await engine.importFile(parquet, options: ImportOptions())
    #expect(copy.rowCount == 3)
    let p = try await engine.snapshot()
    let markdown = Reports.markdown(p, profiles: profile)
    #expect(markdown.contains(v.id.uuidString))
    #expect(markdown.contains(p.sources[0].sha256))
    #expect(markdown.contains("excluded=1"))
    #expect(try String(contentsOf: input, encoding: .utf8) == original)
    await engine.close()
    let moved = dir.appendingPathComponent("moved.vapula")
    try FileManager.default.moveItem(at: url, to: moved)
    let reopened = try await engine.open(at: moved)
    #expect(reopened.datasets.count == 3)
    #expect(reopened.results.count == 1)
    #expect(try await engine.page(datasetID: filtered.id).matchingRows == 3)
    await engine.close()
  }
  @Test func identifierAndValueInjectionCannotExecuteSQL() async throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    let input = dir.appendingPathComponent("in.csv")
    try Data("\"x\"\"; DROP TABLE x;--\",label\n1,hello\n2,world\n".utf8).write(to: input)
    let engine = DataEngine()
    _ = try await engine.create(at: dir.appendingPathComponent("p.vapula"), name: "Injection")
    let v = try await engine.importFile(input, options: ImportOptions())
    let page = try await engine.page(datasetID: v.id, search: "' OR true;--")
    #expect(page.matchingRows == 0)
    let transformed = try await engine.transform(
      datasetID: v.id, operation: .rename(column: v.columns[0].name, name: "safe\"name"))
    #expect(transformed.rowCount == 2)
    let original = try await engine.page(datasetID: v.id)
    #expect(original.matchingRows == 2)
    await engine.close()
  }
  @Test func failedImportIsRecoverableAndExistingExportsAreProtected() async throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    let engine = DataEngine()
    _ = try await engine.create(at: dir.appendingPathComponent("p.vapula"), name: "Recovery")
    await #expect(throws: (any Error).self) {
      try await engine.importFile(
        dir.appendingPathComponent("missing.csv"), options: ImportOptions())
    }
    #expect(try await engine.snapshot().datasets.isEmpty)
    let input = dir.appendingPathComponent("ok.csv")
    try Data("x\n1\n2\n".utf8).write(to: input)
    let v = try await engine.importFile(input, options: ImportOptions())
    await #expect(throws: VapulaError.self) {
      try await engine.exportData(datasetID: v.id, to: input, parquet: false)
    }
    #expect(try String(contentsOf: input, encoding: .utf8) == "x\n1\n2\n")
    await engine.close()
  }
  @Test func regionalCSVAndBOMAreAccepted() async throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    let input = dir.appendingPathComponent("regional.csv")
    try Data("\u{FEFF}fecha;valor\n29/10/2026;1,5\n30/10/2026;2,5\n".utf8).write(to: input)
    let engine = DataEngine()
    _ = try await engine.create(at: dir.appendingPathComponent("p.vapula"), name: "Regional")
    var options = ImportOptions()
    options.delimiter = ";"
    options.decimalSeparator = ","
    options.dateFormat = "%d/%m/%Y"
    let v = try await engine.importFile(input, options: options)
    let p = try await engine.profile(datasetID: v.id)
    #expect(v.rowCount == 2)
    #expect(p.first { $0.column.name == "valor" }?.mean == 2)
    await engine.close()
  }
  @Test func allTypedTransformationsAreReproducible() async throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    let input = dir.appendingPathComponent("t.csv")
    try Data("g,x,text\nA,1,1\nA,2,oops\nB,3,3\n".utf8).write(to: input)
    let engine = DataEngine()
    _ = try await engine.create(at: dir.appendingPathComponent("p.vapula"), name: "Typed")
    var options = ImportOptions()
    options.allText = true
    let v = try await engine.importFile(input, options: options)
    for op: Transformation in [
      .select(columns: ["x"]), .rename(column: "x", name: "new_x"),
      .cast(column: "text", type: .number),
      .derive(column: "x", operation: .multiply, value: 2, name: "twice"),
      .sort(column: "x", ascending: false), .aggregate(group: "g", column: "x", function: .count),
    ] {
      let approval: CastApproval?
      if case .cast(let name, let type) = op {
        approval = try await engine.castImpact(datasetID: v.id, column: name, type: type).approval
      } else { approval = nil }
      let next = try await engine.transform(datasetID: v.id, operation: op, castApproval: approval)
      #expect(next.parentID == v.id)
      #expect(next.operation == op)
    }
    #expect(try await engine.snapshot().datasets.count == 7)
    await engine.close()
  }
  @Test func preCancelledImportCannotCommit() async throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    let engine = DataEngine()
    _ = try await engine.create(at: dir.appendingPathComponent("p.vapula"), name: "Cancel")
    let input = dir.appendingPathComponent("valid.csv")
    try Data("x\n1\n2\n".utf8).write(to: input)
    let operation = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await engine.importFile(input, options: ImportOptions())
    }
    await #expect(throws: CancellationError.self) { try await operation.value }
    #expect(try await engine.snapshot().datasets.isEmpty)
    await engine.close()
  }
  @Test func futureManifestSchemaIsRejected() throws {
    let dir = try temporary()
    defer { try? FileManager.default.removeItem(at: dir) }
    var p = VapulaProject(name: "future")
    p.schemaVersion = 99
    try JSONProjectRepository().save(p, at: dir)
    #expect(throws: VapulaError.self) { try JSONProjectRepository().load(at: dir) }
  }
}

struct PersistenceFailureTests {
  struct FailAfterCreate: ProjectRepository {
    func load(at url: URL) throws -> VapulaProject { try JSONProjectRepository().load(at: url) }
    func save(_ project: VapulaProject, at url: URL) throws {
      guard project.datasets.isEmpty else {
        throw VapulaError.invalid("Simulated atomic manifest write failure")
      }
      try JSONProjectRepository().save(project, at: url)
    }
  }
  @Test func failedManifestWriteLeavesNoReferencedPartialVersion() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "vapula-write-failure-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("source.csv")
    try Data("x\n1\n2\n".utf8).write(to: source)
    let projectURL = root.appendingPathComponent("project.vapula")
    let engine = DataEngine(repository: FailAfterCreate())
    _ = try await engine.create(at: projectURL, name: "Failure")
    await #expect(throws: VapulaError.self) {
      try await engine.importFile(source, options: ImportOptions())
    }
    #expect(try await engine.snapshot().datasets.isEmpty)
    await engine.close()
    let reopened = try await DataEngine().open(at: projectURL)
    #expect(reopened.datasets.isEmpty)
    #expect(try String(contentsOf: source, encoding: .utf8) == "x\n1\n2\n")
  }
  @Test func largeIntegerDistinctCountsAreExactAndRemoteAndGlobPathsAreRejected() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "vapula-integer-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appendingPathComponent("integer.csv")
    try Data("x\n9007199254740992\n9007199254740993\n".utf8).write(to: source)
    let engine = DataEngine()
    _ = try await engine.create(at: root.appendingPathComponent("p.vapula"), name: "Integer")
    let v = try await engine.importFile(source, options: ImportOptions())
    let profile = try await engine.profile(datasetID: v.id)
    #expect(profile.first?.distinct == 2)
    #expect(profile.first?.minimum == "9007199254740992")
    #expect(profile.first?.maximum == "9007199254740993")
    let remote = try #require(URL(string: "https://example.com/data.csv"))
    await #expect(throws: VapulaError.self) {
      try await engine.preview(remote, options: ImportOptions())
    }
    let glob = root.appendingPathComponent("*.csv")
    await #expect(throws: VapulaError.self) {
      try await engine.preview(glob, options: ImportOptions())
    }
    await engine.close()
  }
}
