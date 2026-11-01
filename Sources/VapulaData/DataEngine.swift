import CryptoKit
import Foundation
import VapulaCore

/// Serializes each project transaction away from the UI actor. No background polling.
public actor DataEngine {
  var database: Database?
  var connection: Connection?
  var location: URL?
  var project: VapulaProject?
  let repository: any ProjectRepository
  public init(repository: any ProjectRepository = JSONProjectRepository()) {
    self.repository = repository
  }
  static func configuredDatabase(at url: URL?) throws -> Database {
    let config = Database.Configuration()
    for (key, value) in [
      ("threads", "2"), ("memory_limit", "512MB"), ("autoload_known_extensions", "false"),
      ("autoinstall_known_extensions", "false"), ("allow_unsigned_extensions", "false"),
    ] {
      try config.setValue(value, forKey: key)
    }
    let db = try Database(store: url.map { .file(at: $0) } ?? .inMemory, configuration: config)
    let c = try db.connect()
    try c.execute(
      "SET disabled_filesystems='HTTPFileSystem,S3FileSystem,GCSFileSystem,HuggingFaceFileSystem'")
    return db
  }
  public func create(at url: URL, name: String) throws -> VapulaProject {
    guard url.isFileURL, url.pathExtension == "vapula",
      FileManager.default.fileExists(atPath: url.path) == false
    else { throw VapulaError.invalid("Choose a new .vapula package path.") }
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    do {
      let db = try Self.configuredDatabase(at: url.appendingPathComponent("data.duckdb"))
      let p = VapulaProject(name: name)
      try repository.save(p, at: url)
      database = db
      connection = try db.connect()
      location = url
      project = p
      return p
    } catch {
      try? FileManager.default.removeItem(at: url)
      throw error
    }
  }
  public func open(at url: URL) throws -> VapulaProject {
    guard url.isFileURL,
      FileManager.default.fileExists(atPath: url.appendingPathComponent("data.duckdb").path)
    else { throw VapulaError.invalid("Missing project database.") }
    let p = try repository.load(at: url)
    let db = try Self.configuredDatabase(at: url.appendingPathComponent("data.duckdb"))
    let c = try db.connect()
    for v in p.datasets {
      // Only physical internal tables can be addressed by a manifest. Views are not accepted.
      let r = try c.read(
        "SELECT count(*)::BIGINT FROM duckdb_tables() WHERE table_name=\(SQL.literal(v.tableName)) AND internal=false"
      )
      guard r[0].cast(to: Int.self)[0] == 1 else {
        throw VapulaError.invalid("Dataset table is missing or is not a physical table.")
      }
    }
    database = db
    connection = c
    location = url
    project = p
    return p
  }
  public func close() {
    connection = nil
    database = nil
    location = nil
    project = nil
  }
  public func snapshot() throws -> VapulaProject {
    guard let project else { throw VapulaError.invalid("Open a project first.") }
    return project
  }
  func context() throws -> (Connection, URL, VapulaProject) {
    guard let connection, let location, let project else {
      throw VapulaError.invalid("Open a project first.")
    }
    return (connection, location, project)
  }
  func version(_ id: UUID) throws -> DatasetVersion {
    guard let v = project?.datasets.first(where: { $0.id == id }) else {
      throw VapulaError.invalid("Unknown dataset version.")
    }
    return v
  }
  func column(_ name: String, in v: DatasetVersion) throws -> String {
    guard v.columns.contains(where: { $0.name == name }) else {
      throw VapulaError.invalid("Unknown column: \(name)")
    }
    return try SQL.identifier(name)
  }
  func persist(_ p: VapulaProject) throws {
    guard let location else { throw VapulaError.invalid("No project.") }
    var updated = p
    updated.modifiedAt = Date()
    try repository.save(updated, at: location)
    project = updated
  }
  func metadata(_ v: DatasetVersion, using c: Connection) throws -> DatasetVersion {
    var out = v
    let r = try c.read("DESCRIBE \(v.tableName)")
    out.columns = (0..<r.rowCount).compactMap { i in
      guard let n = r[0].cast(to: String.self)[i], let t = r[1].cast(to: String.self)[i] else {
        return nil
      }
      return ColumnDefinition(name: n, physicalType: t)
    }
    guard out.columns.isEmpty == false, out.columns.count <= 256 else {
      throw VapulaError.invalid("Datasets must have between 1 and 256 columns.")
    }
    out.rowCount = try scalarInt("SELECT count(*)::BIGINT FROM \(v.tableName)", c)
    return out
  }
  func scalarInt(_ sql: String, _ c: Connection) throws -> Int {
    try c.read(sql)[0].cast(to: Int.self)[0] ?? 0
  }
  static func sourceQuery(_ url: URL, _ options: ImportOptions) throws -> String {
    guard url.isFileURL, ["csv", "tsv", "parquet"].contains(url.pathExtension.lowercased()) else {
      throw VapulaError.invalid("Only local CSV, TSV and Parquet files are supported.")
    }
    guard url.path.contains(where: { "*?[]{}".contains($0) }) == false else {
      throw VapulaError.invalid(
        "Wildcard characters in paths are not supported. Rename the file or its containing folder before importing."
      )
    }
    let path = try SQL.literal(url.path)
    if url.pathExtension.lowercased() == "parquet" { return "read_parquet(\(path))" }
    guard ["auto", ",", ";", "\t", "|"].contains(options.delimiter),
      [".", ","].contains(options.decimalSeparator)
    else { throw VapulaError.invalid("Unsupported delimiter or decimal separator.") }
    let delimiter =
      url.pathExtension.lowercased() == "tsv" && options.delimiter == "auto"
      ? "\t" : options.delimiter
    let delim = delimiter == "auto" ? "" : ", delim=\(try SQL.literal(delimiter))"
    let date =
      options.dateFormat.isEmpty ? "" : ", dateformat=\(try SQL.literal(options.dateFormat))"
    return
      "read_csv(\(path), auto_detect=true, header=\(options.header), all_varchar=\(options.allText), decimal_separator=\(try SQL.literal(options.decimalSeparator)), ignore_errors=false\(delim)\(date))"
  }
  public func preview(_ url: URL, options: ImportOptions) throws -> (
    columns: [ColumnDefinition], rows: [DataRow]
  ) {
    try Task.checkCancellation()
    let db = try Self.configuredDatabase(at: nil)
    let c = try db.connect()
    let source = try Self.sourceQuery(url, options)
    let described = try c.read("DESCRIBE SELECT * FROM \(source)")
    let columns = (0..<described.rowCount).compactMap { i -> ColumnDefinition? in
      guard let n = described[0].cast(to: String.self)[i],
        let t = described[1].cast(to: String.self)[i]
      else { return nil }
      return ColumnDefinition(name: n, physicalType: t)
    }
    guard columns.count <= 256 else {
      throw VapulaError.invalid("This version supports at most 256 columns.")
    }
    let projection = try columns.map { "CAST(\(try SQL.identifier($0.name)) AS VARCHAR)" }.joined(
      separator: ",")
    let result = try c.read("SELECT \(projection) FROM \(source) LIMIT 20")
    return (columns, Self.rows(result, offset: 0))
  }
  public func importFile(_ url: URL, options: ImportOptions) throws -> DatasetVersion {
    try Task.checkCancellation()
    let (c, _, p) = try context()
    let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
    let bytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
    if url.pathExtension.lowercased() != "parquet" {
      let h = try FileHandle(forReadingFrom: url)
      defer { try? h.close() }
      let sample = try h.read(upToCount: 65536) ?? Data()
      // Ignore an incomplete multibyte suffix, but reject invalid UTF-8 within the sample and UTF-16 BOMs.
      let trimmed = sample.count == 65536 ? sample.dropLast(4) : sample[...]
      guard sample.starts(with: [0xFF, 0xFE]) == false, sample.starts(with: [0xFE, 0xFF]) == false,
        String(data: Data(trimmed), encoding: .utf8) != nil
          || (0...3).contains(where: {
            String(data: Data(trimmed.dropLast($0)), encoding: .utf8) != nil
          })
      else {
        throw VapulaError.invalid(
          "Only UTF-8 (with or without BOM) is supported. Convert the encoding and retry.")
      }
    }
    let hash = try Self.sha256(url)
    let source = DataSource(
      name: url.lastPathComponent, bytes: bytes, sha256: hash,
      format: url.pathExtension.lowercased(), options: options)
    var v = DatasetVersion(name: url.deletingPathExtension().lastPathComponent, sourceID: source.id)
    let query = try Self.sourceQuery(url, options)
    try c.execute("BEGIN TRANSACTION")
    do {
      try c.execute("CREATE TABLE \(v.tableName) AS SELECT * FROM \(query)")
      v = try metadata(v, using: c)
      guard try Self.sha256(url) == hash else {
        throw VapulaError.invalid("The source changed during import. Retry with a stable file.")
      }
      try Task.checkCancellation()
      try c.execute("COMMIT")
    } catch {
      try? c.execute("ROLLBACK")
      throw error
    }
    var updated = p
    updated.sources.append(source)
    updated.datasets.append(v)
    do {
      try c.execute("CHECKPOINT")
      try persist(updated)
    } catch {
      try? c.execute("DROP TABLE \(v.tableName)")
      throw error
    }
    return v
  }
  static func sha256(_ url: URL) throws -> String {
    let h = try FileHandle(forReadingFrom: url)
    defer { try? h.close() }
    var hasher = SHA256()
    while let chunk = try h.read(upToCount: 1024 * 1024), chunk.isEmpty == false {
      try Task.checkCancellation()
      hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }
  static func rows(_ r: OwnedQuery, offset: Int) -> [DataRow] {
    let columns = (0..<r.columnCount).map { r[$0].cast(to: String.self) }
    return (0..<r.rowCount).map { i in DataRow(id: offset + Int(i), cells: columns.map { $0[i] }) }
  }
}
