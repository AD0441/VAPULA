import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import Testing
import VapulaCore
import VapulaReports

struct PDFReportTests {
  private func fixture(resultCount: Int = 2) -> VapulaProject {
    var project = VapulaProject(name: "Laboratorio sintético de exportación")
    let source = DataSource(
      name: "muestra-sintetica.csv", bytes: 1234,
      sha256: String(repeating: "a1", count: 32), format: "csv", options: ImportOptions())
    project.sources = [source]
    var dataset = DatasetVersion(name: "Datos sintéticos", sourceID: source.id)
    dataset.rowCount = 42
    dataset.columns = [ColumnDefinition(name: "medida", physicalType: "DOUBLE")]
    project.datasets = [dataset]
    project.results = (0..<resultCount).map { index in
      AnalysisResult(
        datasetID: dataset.id,
        specification: AnalysisSpecification(
          method: .welch, x: "medida", group: "grupo", groupA: "A", groupB: "B"),
        validCount: 40, excludedCount: 2,
        metrics: [
          "difference_a_minus_b": Double(index) + 1.25, "p_two_sided": 0.03125, "ci_lower": -0.5,
          "ci_upper": 3.0,
        ],
        warnings: ["No se establece causalidad. Comprueba independencia de las observaciones."],
        procedure: "H0: μA = μB; H1: μA ≠ μB. t de Welch bilateral, exclusión de pares no finitos.")
    }
    return project
  }

  @Test func pdfContainsReadableResultsAndProvenance() throws {
    let project = fixture()
    let data = try PDFReport.data(project: project)
    #expect(data.starts(with: Data("%PDF-".utf8)))
    let document = try #require(PDFDocument(data: data))
    #expect(document.pageCount >= 1)
    let text = try #require(document.string)
    #expect(text.contains("VAPULA"))
    #expect(text.contains("Laboratorio sintético de exportación"))
    #expect(text.contains("muestra-sintetica.csv"))
    #expect(text.contains(String(repeating: "a1", count: 32)))
    #expect(text.contains(project.datasets[0].id.uuidString))
    #expect(text.contains(project.results[0].id.uuidString))
    #expect(text.contains("Observaciones válidas: 40"))
    #expect(text.contains("excluidas: 2"))
    #expect(text.contains("0.03125"))
    #expect(text.contains("Diferencia A"))
    #expect(text.contains("p bilateral"))
    #expect(text.contains("μA"))
    #expect(text.contains("causalidad"))
    #expect(text.contains("Página 1"))
    #expect(text.contains("| Metric |") == false)
    #expect(text.contains("## Analyses") == false)
    if let destination = ProcessInfo.processInfo.environment["VAPULA_PDF_SAMPLE"] {
      try data.write(to: URL(fileURLWithPath: destination), options: .atomic)
    }
  }

  @Test func selectedResultExportDoesNotLeakOtherResults() throws {
    let project = fixture(resultCount: 3)
    let selected = project.results[1]
    let document = try #require(
      PDFDocument(data: PDFReport.data(project: project, results: [selected])))
    let text = try #require(document.string)
    #expect(text.contains(selected.id.uuidString))
    #expect(text.contains(project.results[0].id.uuidString) == false)
    #expect(text.contains(project.results[2].id.uuidString) == false)
    #expect(text.contains(project.datasets[0].id.uuidString))
    #expect(text.contains("1 análisis"))
  }

  @Test func longReportsPaginateWithoutDroppingLastResultOrFooter() throws {
    var project = fixture(resultCount: 24)
    let longWarning = Array(
      repeating: "Supuestos, exclusiones y limitaciones del análisis sintético.", count: 25
    ).joined(separator: " ")
    for index in project.results.indices {
      project.results[index].warnings.append(longWarning)
      project.results[index].metrics[
        "a_very_long_but_legitimate_metric_name_with_units_and_method_information"] = 123.456789
    }
    let document = try #require(PDFDocument(data: PDFReport.data(project: project)))
    #expect(document.pageCount > 10)
    let text = try #require(document.string)
    #expect(text.contains(project.results[0].id.uuidString))
    #expect(text.contains(try #require(project.results.last).id.uuidString))
    for index in 0..<document.pageCount {
      let page = try #require(document.page(at: index))
      let pageText = try #require(page.string)
      #expect(pageText.contains("Página \(index + 1)"))
      #expect(pageText.contains("VAPULA"))
      #expect(page.bounds(for: .mediaBox).width > 590)
      #expect(page.bounds(for: .mediaBox).height > 840)
    }
  }

  private func plotPNG() throws -> Data {
    let context = try #require(CGContext(data: nil, width: 600, height: 320, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 600, height: 320))
    context.setFillColor(CGColor(red: 0.12, green: 0.4, blue: 0.7, alpha: 1))
    for (i, height) in [70, 140, 230, 150, 80].enumerated() { context.fill(CGRect(x: 40 + i * 105, y: 30, width: 80, height: height)) }
    let image = try #require(context.makeImage()), data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
  }
  @Test func figuresTravelWithPDFAndMarkdownWithoutOverwritingFiles() throws {
    let project = fixture(), png = try plotPNG()
    let figure = ReportFigure(title: "Distribución [sintética]", datasetID: project.datasets[0].id, caption: "Cinco barras de control.", png: png)
    let pdf = try PDFReport.data(project: project, figures: [figure])
    let document = try #require(PDFDocument(data: pdf))
    #expect(try #require(document.string).contains("Distribución [sintética]"))
    #expect(try #require(document.string).contains("Cinco barras de control."))
    #expect(pdf.count > (try PDFReport.data(project: project)).count)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vapula-figures-\(UUID())")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let md = dir.appendingPathComponent("Informe de prueba.md"), image = dir.appendingPathComponent("Informe de prueba-grafico-1.png")
    try Reports.writeMarkdown(project, figures: [figure], to: md)
    #expect(try Data(contentsOf: image) == png)
    #expect(try String(contentsOf: md, encoding: .utf8).contains("Informe%20de%20prueba-grafico-1.png"))
    #expect(throws: VapulaError.self) { try Reports.writeMarkdown(project, figures: [figure], to: md) }
    try FileManager.default.removeItem(at: md)
    #expect(throws: VapulaError.self) { try Reports.writeMarkdown(project, figures: [figure], to: md) }
    #expect(!FileManager.default.fileExists(atPath: md.path))
    #expect(try Data(contentsOf: image) == png)
    if let destination = ProcessInfo.processInfo.environment["VAPULA_PDF_FIGURE_SAMPLE"] { try pdf.write(to: URL(fileURLWithPath: destination)) }
  }
  @Test func foreignAndInvalidFiguresFailExplicitly() throws {
    let project = fixture()
    let foreign = ReportFigure(title: "Fuera", datasetID: UUID(), caption: "", png: try plotPNG())
    #expect(throws: VapulaError.self) { try PDFReport.data(project: project, figures: [foreign]) }
    let invalid = ReportFigure(title: "Rota", datasetID: project.datasets[0].id, caption: "", png: Data("no es una imagen".utf8))
    #expect(throws: VapulaError.self) { try PDFReport.data(project: project, figures: [invalid]) }
  }
  @Test func emptyProjectIsAValidDocumentAndInvalidSelectionsFail() throws {
    let empty = VapulaProject(name: "Proyecto vacío")
    let document = try #require(PDFDocument(data: PDFReport.data(project: empty)))
    #expect(try #require(document.string).contains("No hay análisis incluidos"))
    let foreign = fixture().results[0]
    #expect(throws: VapulaError.self) { try PDFReport.data(project: empty, results: [foreign]) }
    var invalid = fixture()
    invalid.results[0].metrics["invalid"] = .nan
    #expect(throws: VapulaError.self) { try PDFReport.data(project: invalid) }
  }
}
