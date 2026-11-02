import Foundation
import Testing
import VapulaCore
import VapulaData

struct ImportFailureTests {
  @Test func malformedInputExplainsHowToRetryWithoutPublishingInternalSQL() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-import-error-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let engine = DataEngine()
    _ = try await engine.create(at: root.appendingPathComponent("p.vapula"), name: "Import diagnostics")
    let input = root.appendingPathComponent("broken.parquet")
    let bytes = Data("This is deliberately not Parquet".utf8)
    try bytes.write(to: input)
    do {
      _ = try await engine.importFile(input, options: ImportOptions())
      Issue.record("Malformed Parquet unexpectedly imported")
    } catch {
      let message = error.localizedDescription
      #expect(message.contains("broken.parquet") && message.contains("completo"))
      #expect(message.contains("CREATE TABLE") == false && message.contains("SELECT") == false)
    }
    #expect(try await engine.snapshot().datasets.isEmpty)
    #expect(try Data(contentsOf: input) == bytes)
    await engine.close()
  }
}
