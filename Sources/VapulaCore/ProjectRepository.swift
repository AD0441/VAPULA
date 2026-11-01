import Foundation

public protocol ProjectRepository: Sendable {
  func load(at url: URL) throws -> VapulaProject
  func save(_ project: VapulaProject, at url: URL) throws
}
public struct JSONProjectRepository: ProjectRepository {
  public init() {}
  public func load(at url: URL) throws -> VapulaProject {
    let data = try Data(contentsOf: url.appendingPathComponent("manifest.json"))
    let value = try JSONDecoder().decode(VapulaProject.self, from: data)
    guard value.schemaVersion == 1 else {
      throw VapulaError.invalid("Unsupported project schema: \(value.schemaVersion).")
    }
    guard Set(value.datasets.map(\.id)).count == value.datasets.count else {
      throw VapulaError.invalid("Duplicate dataset identifiers in project.")
    }
    try value.workflow?.validate(datasetIDs: Set(value.datasets.map(\.id)), resultIDs: Set(value.results.map(\.id)))
    return value
  }
  public func save(_ project: VapulaProject, at url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(project)
    try data.write(to: url.appendingPathComponent("manifest.json"), options: .atomic)
  }
}
public enum SQL {
  public static func identifier(_ name: String) throws -> String {
    guard name.isEmpty == false, name.utf8.count <= 256, name.contains("\0") == false else {
      throw VapulaError.invalid("Invalid column name.")
    }
    return "\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }
  public static func literal(_ value: String) throws -> String {
    guard value.contains("\0") == false else { throw VapulaError.invalid("NUL is not accepted.") }
    return "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
  }
}
