import Foundation
import PDFKit
import Testing
import VapulaCore
import VapulaData
import VapulaReports

struct ReportAcceptanceTests {
  @Test(arguments: [("9.8.7", "654"), ("0.1.3", "4")])
  func exportsIdentifyTheirProducingVersionAndBuild(release: (String, String)) throws {
    let project = VapulaProject(name: "Identidad del exportador")
    let software = ReportSoftware(version: release.0, build: release.1)
    let expected = "VAPULA \(release.0) (build \(release.1))"
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-identity-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let markdownURL = directory.appendingPathComponent("informe.md")
    try Reports.writeMarkdown(project, figures: [], to: markdownURL, software: software)
    let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
    let pdf = try #require(PDFDocument(data: PDFReport.data(project: project, software: software)))
    #expect(markdown.contains(expected))
    #expect(try #require(pdf.string).contains(expected))
    #expect((pdf.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)?.contains(expected) == true)
    #expect(markdown.contains("0.1 development") == false)
  }

  @Test func anUnversionedExportDoesNotInventARelease() throws {
    let project = VapulaProject(name: "SwiftPM")
    let software = ReportSoftware(version: " \n", build: nil)
    let markdown = Reports.markdown(project, software: software)
    let pdf = try #require(PDFDocument(data: PDFReport.data(project: project, software: software)))
    #expect(markdown.contains("versión del bundle no disponible"))
    #expect(try #require(pdf.string).contains("versión del bundle no disponible"))
    #expect(markdown.contains("0.1 development") == false)
  }

  @Test func representativeDataKeepsVersionsAndSelectedExportsAfterPortableReopen() async throws {
    let fixture = try #require(Bundle.module.url(forResource: "laboratorio", withExtension: "csv", subdirectory: "Fixtures"))
    let original = try Data(contentsOf: fixture)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-v2-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("mediciones.csv")
    try original.write(to: source)
    let package = directory.appendingPathComponent("aceptacion.vapula")
    let engine = DataEngine()
    _ = try await engine.create(at: package, name: "Aceptación V2 · datos sintéticos")
    let input = try await engine.importFile(source, options: ImportOptions())
    #expect(input.rowCount == 31)
    let historical = try await engine.analyze(datasetID: input.id, specification: AnalysisSpecification(method: .descriptive, x: "x"))
    #expect(historical.validCount == 30 && historical.excludedCount == 1)
    let filled = try await engine.transform(datasetID: input.id, operation: .missing(columns: ["x"], action: .mean, policy: MissingPolicy()))
    let first = try #require(try await engine.page(datasetID: filled.id).rows.first)
    let corrected = try await engine.transform(datasetID: filled.id, operation: .editCell(rowID: try #require(first.sourceRowID), column: "x", value: "4.5"))
    let result = try await engine.analyze(datasetID: corrected.id, specification: AnalysisSpecification(method: .descriptive, x: "x"))
    // Original finite X sums to 644. Mean imputation adds 644/30; editing adds 0.5.
    let expectedMean = (644.0 + 644.0 / 30.0 + 0.5) / 31.0
    #expect(abs(try #require(result.metrics["mean"]) - expectedMean) < 1e-12)
    #expect(result.validCount == 31 && result.excludedCount == 0)
    let impact = try await engine.castImpact(datasetID: input.id, column: "id", type: .date)
    #expect(impact.newNulls == 31 && impact.existingNulls == 0)
    await #expect(throws: VapulaError.self) {
      try await engine.transform(datasetID: input.id, operation: .cast(column: "id", type: .date))
    }
    #expect(try await engine.snapshot().datasets.count == 3)
    let conversion = try await engine.transform(datasetID: input.id, operation: .cast(column: "id", type: .date), castApproval: impact.approval)
    #expect(conversion.rowCount == 31)
    await engine.close()
    let moved = directory.appendingPathComponent("portable.vapula")
    try FileManager.default.moveItem(at: package, to: moved)
    let reopened = try await engine.open(at: moved)
    #expect(reopened.datasets.count == 4 && reopened.results.count == 2)
    #expect(try await engine.page(datasetID: input.id).rows.first?.cells[2] == "4")
    #expect(try await engine.page(datasetID: corrected.id).rows.first?.cells[2] == "4.5")
    #expect(try await engine.profile(datasetID: input.id).first { $0.column.name == "x" }?.missing == 1)
    let plan = try ReportSelection.plan(project: reopened, workflow: .inferred(from: reopened), scope: .result(result.id))
    #expect(plan.project.results.map(\.id) == [result.id])
    #expect(plan.project.datasets.map(\.id) == [input.id, filled.id, corrected.id])
    let markdown = Reports.markdown(plan.project)
    let pdf = try #require(PDFDocument(data: PDFReport.data(project: plan.project)))
    let text = try #require(pdf.string)
    for output in [markdown, text] {
      #expect(output.contains(result.id.uuidString))
      #expect(output.contains(historical.id.uuidString) == false)
      #expect(output.contains(conversion.id.uuidString) == false)
      #expect(output.contains(try #require(reopened.sources.first).sha256))
    }
    #expect(try Data(contentsOf: source) == original)
    await engine.close()
    #expect(FileManager.default.fileExists(atPath: moved.appendingPathComponent(".vapula-session").path) == false)
  }
}
