import Cduckdb
import Foundation
import VapulaCore

// The official Swift package supplies the pinned, statically linked DuckDB engine.
// This actor-confined adapter copies scalar values through the public C API;
// no native vector or borrowed element escapes the owning result's lifetime.
typealias DBInt = Int
final class Database {
  enum Store {
    case inMemory
    case file(at: URL)
  }
  final class Configuration {
    var handle: duckdb_config?
    init() { precondition(duckdb_create_config(&handle) == DuckDBSuccess) }
    deinit { duckdb_destroy_config(&handle) }
    func setValue(_ value: String, forKey key: String) throws {
      guard duckdb_set_config(handle, key, value) == DuckDBSuccess else {
        throw VapulaError.invalid("Unsupported DuckDB configuration: \(key)")
      }
    }
  }
  var handle: duckdb_database?
  init(store: Store, configuration: Configuration) throws {
    var failure: UnsafeMutablePointer<CChar>?
    let state: duckdb_state = withExtendedLifetime(configuration) {
      switch store {
      case .inMemory: return duckdb_open_ext(nil, &handle, configuration.handle, &failure)
      case .file(let url):
        return url.path.withCString { duckdb_open_ext($0, &handle, configuration.handle, &failure) }
      }
    }
    defer { if let failure { duckdb_free(UnsafeMutableRawPointer(failure)) } }
    guard state == DuckDBSuccess else {
      throw VapulaError.invalid(
        failure.map { String(cString: $0) } ?? "Cannot open DuckDB database.")
    }
  }
  deinit { duckdb_close(&handle) }
  func connect() throws -> Connection { try Connection(database: self) }
}
final class Connection {
  let database: Database
  var handle: duckdb_connection?
  init(database: Database) throws {
    self.database = database
    guard duckdb_connect(database.handle, &handle) == DuckDBSuccess else {
      throw VapulaError.invalid("Cannot connect to DuckDB.")
    }
  }
  deinit { duckdb_disconnect(&handle) }
  func read(_ sql: String) throws -> OwnedQuery {
    let result = OwnedQuery()
    try result.check(duckdb_query(handle, sql, result.pointer))
    return result
  }
  func execute(_ sql: String) throws { _ = try read(sql) }
}
final class PreparedStatement {
  let connection: Connection
  var handle: duckdb_prepared_statement?
  init(connection: Connection, query: String) throws {
    self.connection = connection
    guard duckdb_prepare(connection.handle, query, &handle) == DuckDBSuccess else {
      throw VapulaError.invalid(
        duckdb_prepare_error(handle).map { String(cString: $0) } ?? "Cannot prepare query.")
    }
  }
  deinit { duckdb_destroy_prepare(&handle) }
  func bind(_ value: String, at index: Int) throws {
    guard index > 0, duckdb_bind_varchar(handle, idx_t(index), value) == DuckDBSuccess else {
      throw VapulaError.invalid("Cannot bind query parameter.")
    }
  }
  func read() throws -> OwnedQuery {
    let result = OwnedQuery()
    try result.check(duckdb_execute_prepared(handle, result.pointer))
    return result
  }
  func execute() throws -> OwnedQuery { try read() }
}
final class OwnedQuery {
  let pointer: UnsafeMutablePointer<duckdb_result>
  init() {
    pointer = .allocate(capacity: 1)
    pointer.initialize(to: duckdb_result())
  }
  deinit {
    duckdb_destroy_result(pointer)
    pointer.deinitialize(count: 1)
    pointer.deallocate()
  }
  func check(_ state: duckdb_state) throws {
    guard state == DuckDBSuccess else {
      throw VapulaError.invalid(
        duckdb_result_error(pointer).map { String(cString: $0) } ?? "DuckDB query failed.")
    }
  }
  var rowCount: Int { Int(duckdb_row_count(pointer)) }
  var columnCount: Int { Int(duckdb_column_count(pointer)) }
  subscript(index: Int) -> OwnedColumn { OwnedColumn(source: self, index: index) }
  func isNull(_ column: Int, _ row: Int) -> Bool {
    duckdb_value_is_null(pointer, idx_t(column), idx_t(row))
  }
  func string(_ column: Int, _ row: Int) -> String? {
    withExtendedLifetime(self) {
      guard isNull(column, row) == false,
        let text = duckdb_value_varchar(pointer, idx_t(column), idx_t(row))
      else { return nil }
      defer { duckdb_free(UnsafeMutableRawPointer(text)) }
      return String(cString: text)
    }
  }
  func number(_ column: Int, _ row: Int) -> Double? {
    withExtendedLifetime(self) {
      isNull(column, row) ? nil : duckdb_value_double(pointer, idx_t(column), idx_t(row))
    }
  }
  func integer(_ column: Int, _ row: Int) -> Int? {
    withExtendedLifetime(self) {
      isNull(column, row) ? nil : Int(duckdb_value_int64(pointer, idx_t(column), idx_t(row)))
    }
  }
  func boolean(_ column: Int, _ row: Int) -> Bool? {
    withExtendedLifetime(self) {
      isNull(column, row) ? nil : duckdb_value_boolean(pointer, idx_t(column), idx_t(row))
    }
  }
}
struct OwnedColumn {
  let source: OwnedQuery
  let index: Int
  func cast(to type: String.Type) -> OwnedValues<String> {
    OwnedValues { source.string(index, $0) }
  }
  func cast(to type: Double.Type) -> OwnedValues<Double> {
    OwnedValues { source.number(index, $0) }
  }
  func cast(to type: Int.Type) -> OwnedValues<Int> { OwnedValues { source.integer(index, $0) } }
  func cast(to type: Bool.Type) -> OwnedValues<Bool> { OwnedValues { source.boolean(index, $0) } }
}
struct OwnedValues<Value> {
  let decode: (Int) -> Value?
  subscript(index: Int) -> Value? { decode(index) }
}
