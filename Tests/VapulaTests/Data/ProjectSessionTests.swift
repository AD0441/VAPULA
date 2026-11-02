import Darwin
import Foundation
import Testing
import VapulaCore
@testable import VapulaData

// Bound native engine subprocesses on the 8 GB target host. Four concurrent exit tests
// produced unexpected SIGTRAP terminations in the full suite; retain exact signal diagnostics.
@Suite(.serialized)
struct ProjectSessionTests {
  @Test func anotherWriterIsRejectedAndCleanCloseReleasesTheLease() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-lease-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let package = root.appendingPathComponent("p.vapula")
    let first = DataEngine(), second = DataEngine()
    let project = try await first.create(at: package, name: "Writer")
    await #expect(throws: VapulaError.self) { try await second.open(at: package) }
    #expect(try await first.snapshot().id == project.id)
    await first.close()
    #expect(try await second.open(at: package).id == project.id)
    #expect(await second.recoveryNotice == nil)
    await second.close()
    #expect(FileManager.default.fileExists(atPath: package.appendingPathComponent(".vapula-session").path) == false)
  }

  @Test func failedOpenKeepsTheCurrentProjectAndReleasesTheCandidateLease() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-bad-open-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = DataEngine(), second = DataEngine()
    let a = try await first.create(at: root.appendingPathComponent("a.vapula"), name: "A")
    let bURL = root.appendingPathComponent("b.vapula")
    let b = try await second.create(at: bURL, name: "B"); await second.close()
    let manifest = bURL.appendingPathComponent("manifest.json")
    let bytes = try Data(contentsOf: manifest)
    try Data("{interrupted".utf8).write(to: manifest, options: .atomic)
    await #expect(throws: VapulaError.self) { try await first.open(at: bURL) }
    #expect(try await first.snapshot().id == a.id)
    try bytes.write(to: manifest, options: .atomic)
    #expect(try await second.open(at: bURL).id == b.id)
    await first.close(); await second.close()
  }

  @Test func interruptedProjectWithInconsistentMetadataIsNotSilentlyRepaired() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-bad-metadata-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let engine = DataEngine(), package = root.appendingPathComponent("p.vapula")
    _ = try await engine.create(at: package, name: "Metadata")
    let source = root.appendingPathComponent("source.csv")
    try Data("x\n1\n2\n".utf8).write(to: source)
    _ = try await engine.importFile(source, options: ImportOptions())
    var project = try await engine.snapshot(); await engine.close()
    project.datasets[0].rowCount = 99
    try JSONProjectRepository().save(project, at: package)
    try Data("interrupted".utf8).write(to: package.appendingPathComponent(".vapula-session"))
    let before = try Data(contentsOf: package.appendingPathComponent("manifest.json"))
    await #expect(throws: VapulaError.self) { try await engine.open(at: package) }
    #expect(try Data(contentsOf: package.appendingPathComponent("manifest.json")) == before)
    #expect(FileManager.default.fileExists(atPath: package.appendingPathComponent(".vapula-session").path))
    project.datasets[0].rowCount = 2
    try JSONProjectRepository().save(project, at: package)
    #expect(try await engine.open(at: package).datasets[0].rowCount == 2)
    await engine.close()
  }

  @Test func forcedExitDuringImportKeepsThePreviousManifest() async throws {
    let result = try await #require(processExitsWith: .failure, observing: [\.standardOutputContent, \.standardErrorContent]) {
      try await RecoveryProbe.run(.importBeforeManifest)
    }
    try await RecoveryProbe.verify(result, versions: 0, orphans: 1)
  }
  @Test func forcedExitAfterTransformCommitPreservesBothPhysicalTables() async throws {
    let result = try await #require(processExitsWith: .failure, observing: [\.standardOutputContent, \.standardErrorContent]) {
      try await RecoveryProbe.run(.transformBeforeManifest)
    }
    try await RecoveryProbe.verify(result, versions: 1, orphans: 1)
  }
  @Test func forcedExitAfterAtomicSaveRecoversTheNewVersion() async throws {
    let result = try await #require(processExitsWith: .failure, observing: [\.standardOutputContent, \.standardErrorContent]) {
      try await RecoveryProbe.run(.afterManifest)
    }
    try await RecoveryProbe.verify(result, versions: 2, orphans: 0)
  }
  @Test func forcedExitDuringTransactionDiscardsOnlyUncommittedWork() async throws {
    let result = try await #require(processExitsWith: .failure, observing: [\.standardOutputContent, \.standardErrorContent]) {
      try await RecoveryProbe.run(.duringTransaction)
    }
    try await RecoveryProbe.verify(result, versions: 1, orphans: 0)
  }
}

private enum CrashPhase: Sendable { case importBeforeManifest, transformBeforeManifest, afterManifest, duringTransaction }
private struct CrashRepository: ProjectRepository {
  let phase: CrashPhase
  func load(at url: URL) throws -> VapulaProject { try JSONProjectRepository().load(at: url) }
  func save(_ project: VapulaProject, at url: URL) throws {
    if phase == .importBeforeManifest && project.datasets.count == 1 { RecoveryProbe.terminate() }
    if phase == .transformBeforeManifest && project.datasets.count == 2 { RecoveryProbe.terminate() }
    try JSONProjectRepository().save(project, at: url)
    if phase == .afterManifest && project.datasets.count == 2 { RecoveryProbe.terminate() }
  }
}
private enum RecoveryProbe {
  static func terminate() -> Never {
    Darwin.kill(getpid(), SIGKILL)
    fatalError("SIGKILL did not terminate the recovery probe")
  }
  static func run(_ phase: CrashPhase) async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-crash-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let engine = DataEngine(repository: CrashRepository(phase: phase))
    _ = try await engine.create(at: root.appendingPathComponent("p.vapula"), name: "Crash recovery")
    let input = root.appendingPathComponent("input.csv")
    try Data("x\n1\n2\n".utf8).write(to: input)
    try FileHandle.standardOutput.write(contentsOf: Data("VAPULA_CRASH_ROOT=\(root.path)\n".utf8))
    let source = try await engine.importFile(input, options: ImportOptions())
    if phase == .duringTransaction { try await engine.crashDuringTransaction(source.id) }
    _ = try await engine.transform(datasetID: source.id, operation: .filter(column: "x", comparison: .greater, value: "1"))
    terminate()
  }
  static func verify(_ result: ExitTest.Result, versions: Int, orphans: Int) async throws {
    try #require(result.exitStatus == .signal(SIGKILL), "Unexpected child termination: \(String(decoding: result.standardErrorContent, as: UTF8.self))")
    let output = result.standardOutputContent
    let line = try #require(String(decoding: output, as: UTF8.self).split(separator: "\n").first { $0.hasPrefix("VAPULA_CRASH_ROOT=") })
    let root = URL(fileURLWithPath: String(line.dropFirst("VAPULA_CRASH_ROOT=".count)))
    try #require(root.lastPathComponent.hasPrefix("vapula-crash-") && root.deletingLastPathComponent().resolvingSymlinksInPath() == FileManager.default.temporaryDirectory.resolvingSymlinksInPath())
    defer { try? FileManager.default.removeItem(at: root) }
    let engine = DataEngine()
    let project = try await engine.open(at: root.appendingPathComponent("p.vapula"))
    #expect(project.datasets.count == versions)
    let notice = try #require(await engine.recoveryNotice)
    #expect(notice.interrupted && notice.verifiedVersions == versions && notice.unreferencedTables == orphans)
    for version in project.datasets {
      #expect(try await engine.page(datasetID: version.id).matchingRows == version.rowCount)
    }
    #expect(try String(contentsOf: root.appendingPathComponent("input.csv"), encoding: .utf8) == "x\n1\n2\n")
    await engine.close()
  }
}
private extension DataEngine {
  func crashDuringTransaction(_ id: UUID) throws {
    let (c, _, _) = try context()
    let source = try version(id)
    let table = "v_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    try c.execute("BEGIN TRANSACTION")
    try c.execute("CREATE TABLE \(table) AS SELECT * FROM \(source.tableName)")
    RecoveryProbe.terminate()
  }
}
