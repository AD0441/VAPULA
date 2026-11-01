import Foundation
import Testing
import VapulaCore
import VapulaData

struct CleaningTests {
  private func setup(_ text: String) async throws -> (DataEngine, URL, URL, DatasetVersion) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-clean-\(UUID())")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let csv = dir.appendingPathComponent("input.csv"); try Data(text.utf8).write(to: csv)
    let engine = DataEngine()
    _ = try await engine.create(at: dir.appendingPathComponent("project.vapula"), name: "Limpieza sintética")
    return (engine, dir, csv, try await engine.importFile(csv, options: ImportOptions()))
  }
  @Test func missingPreviewAndAllReplacementMethodsPreserveTheSource() async throws {
    let original = "id,x,label\n1,2,A\n2,, \n3,6,B\n4,10,A\n5,,\n"
    let (engine, dir, csv, source) = try await setup(original)
    defer { try? FileManager.default.removeItem(at: dir) }
    let impact = try await engine.missingImpact(datasetID: source.id, columns: ["x", "label"])
    #expect(impact.counts["x"] == 2 && impact.counts["label"] == 2)
    #expect(impact.affectedRows == 2 && impact.affectedCells == 4)
    for action in [MissingAction.mean, .median, .constant("6")] {
      let filled = try await engine.transform(datasetID: source.id, operation: .missing(columns: ["x"], action: action, policy: MissingPolicy()))
      let profile = try #require(try await engine.profile(datasetID: filled.id).first { $0.column.name == "x" })
      #expect(profile.valid == 5 && profile.missing == 0)
      #expect(profile.mean == 6)
      #expect(filled.parentID == source.id)
    }
    let mode = try await engine.transform(datasetID: source.id, operation: .missing(columns: ["label"], action: .mode, policy: MissingPolicy()))
    let rows = try await engine.page(datasetID: mode.id).rows
    #expect(rows[1].cells[2] == "A" && rows[4].cells[2] == "A")
    #expect(try await engine.profile(datasetID: source.id).first { $0.column.name == "x" }?.missing == 2)
    #expect(try String(contentsOf: csv, encoding: .utf8) == original)
    await engine.close()
  }
  @Test func removalIsExplicitAndCannotDropEveryColumn() async throws {
    let (engine, dir, _, source) = try await setup("id,x,label\n1,2,A\n2,,\n3,6,B\n")
    defer { try? FileManager.default.removeItem(at: dir) }
    let removed = try await engine.transform(datasetID: source.id, operation: .missing(columns: ["x"], action: .dropRows, policy: MissingPolicy()))
    #expect(removed.rowCount == 2 && removed.columns.count == 3)
    let selected = try await engine.transform(datasetID: source.id, operation: .missing(columns: ["x", "label"], action: .dropColumns, policy: MissingPolicy()))
    #expect(selected.columns.map(\.name) == ["id"])
    let all = try await engine.transform(datasetID: source.id, operation: .select(columns: ["x", "label"]))
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: all.id, operation: .missing(columns: ["x", "label"], action: .dropColumns, policy: MissingPolicy()))
    }
    await engine.close()
  }
  @Test func nonfinitePolicyIsVisibleAndEmptyNumericColumnsDoNotInventAverages() async throws {
    let (engine, dir, _, source) = try await setup("id,x,empty\n1,1,\n2,NaN,\n3,inf,\n4,,\n")
    defer { try? FileManager.default.removeItem(at: dir) }
    let strict = try await engine.missingImpact(datasetID: source.id, columns: ["x"])
    let nullOnly = try await engine.missingImpact(datasetID: source.id, columns: ["x"], policy: MissingPolicy(blankText: false, nonFiniteNumbers: false))
    #expect(strict.affectedRows == 3 && nullOnly.affectedRows == 1)
    let filled = try await engine.transform(datasetID: source.id, operation: .missing(columns: ["x"], action: .mean, policy: MissingPolicy()))
    #expect(try await engine.profile(datasetID: filled.id).first { $0.column.name == "x" }?.mean == 1)
    let typed = try await engine.transform(datasetID: source.id, operation: .cast(column: "empty", type: .number))
    let count = try await engine.snapshot().datasets.count
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: typed.id, operation: .missing(columns: ["empty"], action: .mean, policy: MissingPolicy()))
    }
    #expect(try await engine.snapshot().datasets.count == count)
    await engine.close()
  }
  @Test func manualCorrectionUsesSourceIdentityAfterSearchingAndSorting() async throws {
    let (engine, dir, _, source) = try await setup("id,x,label\n10,99,other\n20,3,needle\n30,4,last\n")
    defer { try? FileManager.default.removeItem(at: dir) }
    let row = try #require(try await engine.page(datasetID: source.id, search: "needle", sort: "x", ascending: false).rows.first)
    #expect(row.id == 0 && row.sourceRowID == 1)
    let corrected = try await engine.transform(datasetID: source.id, operation: .editCell(rowID: try #require(row.sourceRowID), column: "x", value: "7"))
    let rows = try await engine.page(datasetID: corrected.id).rows
    #expect(rows[0].cells[1] == "99" && rows[1].cells[1] == "7")
    let removed = try await engine.transform(datasetID: corrected.id, operation: .removeRows(rowIDs: [0, 2]))
    #expect(removed.rowCount == 1)
    #expect(try await engine.page(datasetID: removed.id).rows.first?.cells[0] == "20")
    #expect(try await engine.page(datasetID: source.id).rows[1].cells[1] == "3")
    await engine.close()
  }
  @Test func addedValuesAreTypedAndNeverExecuteUserText() async throws {
    let (engine, dir, _, source) = try await setup("id,x,label\n1,2,A\n2,3,B\n")
    defer { try? FileManager.default.removeItem(at: dir) }
    let value = "a'); DROP TABLE imaginary; --"
    let column = try await engine.transform(datasetID: source.id, operation: .addColumn(name: "nota", type: .text, value: value))
    #expect(try await engine.page(datasetID: column.id).rows[0].cells[3] == value)
    let row = try await engine.transform(datasetID: column.id, operation: .appendRow(values: ["id": "3", "x": "5", "label": value, "nota": nil]))
    #expect(row.rowCount == 3)
    let appended = try #require(try await engine.page(datasetID: row.id).rows.last)
    #expect(appended.cells[2] == value && appended.cells[3] == nil)
    let count = try await engine.snapshot().datasets.count
    await #expect(throws: (any Error).self) {
      try await engine.transform(datasetID: row.id, operation: .editCell(rowID: 0, column: "x", value: "oops"))
    }
    #expect(try await engine.snapshot().datasets.count == count)
    await engine.close()
  }
  @Test func modeKeepsLargeIntegerPrecisionAndBreaksTiesDeterministically() async throws {
    let (engine, dir, _, source) = try await setup("id,x\n1,9007199254740993\n2,9007199254740995\n3,\n")
    defer { try? FileManager.default.removeItem(at: dir) }
    let filled = try await engine.transform(datasetID: source.id, operation: .missing(columns: ["x"], action: .mode, policy: MissingPolicy()))
    #expect(try await engine.page(datasetID: filled.id).rows[2].cells[1] == "9007199254740993")
    await engine.close()
  }
  @Test func userRowidColumnCannotRedirectCellEdits() async throws {
    let (engine, dir, _, source) = try await setup("rowid,x\n99,1\n77,2\n")
    defer { try? FileManager.default.removeItem(at: dir) }
    #expect(try await engine.page(datasetID: source.id).rows.allSatisfy { $0.sourceRowID == nil })
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: source.id, operation: .editCell(rowID: 99, column: "x", value: "3"))
    }
    await engine.close()
  }
}
