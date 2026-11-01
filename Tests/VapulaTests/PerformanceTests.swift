import Darwin
import Foundation
import Testing
import VapulaCore
import VapulaData

struct PerformanceTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["VAPULA_BENCHMARK"] == "1"))
  func millionRowsImportProfileAndPage() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "vapula-benchmark-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("million.csv")
    FileManager.default.createFile(atPath: file.path, contents: Data("id,group,x,y\n".utf8))
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    for batch in 0..<100 {
      var text = ""
      text.reserveCapacity(400_000)
      for i in (batch * 10_000)..<((batch + 1) * 10_000) {
        text += "\(i),\(i%3),\(Double(i%10000)/10),\(Double(i%10000)/5+3)\n"
      }
      try handle.write(contentsOf: Data(text.utf8))
    }
    try handle.close()
    let engine = DataEngine()
    _ = try await engine.create(
      at: root.appendingPathComponent("bench.vapula"), name: "Synthetic million")
    let start = Date()
    let v = try await engine.importFile(file, options: ImportOptions())
    let importTime = Date().timeIntervalSince(start)
    let pageStart = Date()
    let page = try await engine.page(datasetID: v.id, offset: 999_900)
    let pageTime = Date().timeIntervalSince(pageStart)
    let profileStart = Date()
    let profile = try await engine.profile(datasetID: v.id)
    let profileTime = Date().timeIntervalSince(profileStart)
    #expect(v.rowCount == 1_000_000)
    #expect(page.rows.count == 100)
    #expect(profile.count == 4)
    let databaseBytes =
      (try FileManager.default.attributesOfItem(
        atPath: root.appendingPathComponent("bench.vapula/data.duckdb").path)[.size] as? NSNumber)?
      .intValue ?? 0
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    #if DEBUG
      let buildConfiguration = "debug"
    #else
      let buildConfiguration = "release"
    #endif
    let report: [String: Any] = [
      "rows": v.rowCount, "importSeconds": importTime, "page100AtOffset999900Seconds": pageTime,
      "fullProfileSeconds": profileTime, "peakRSSBytes": usage.ru_maxrss,
      "databaseBytes": databaseBytes, "build": buildConfiguration, "cpu": "Apple M1", "memoryGB": 8,
    ]
    let data = try JSONSerialization.data(
      withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    if let path = ProcessInfo.processInfo.environment["VAPULA_BENCHMARK_OUTPUT"] {
      try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }
    print(String(decoding: data, as: UTF8.self))
    await engine.close()
  }
}
