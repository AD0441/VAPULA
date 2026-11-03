import CoreGraphics
import CoreText
import ImageIO
import Foundation
import VapulaCore

/// A self-contained vector PDF. CoreText performs pagination without a web view,
/// print dialog, network access, or a Python/R runtime.
public enum PDFReport {
  /// Exports the project, or an explicitly selected set of its analysis results.
  /// Sources and dataset ancestors are retained to keep each result traceable.
  public static func data(
    project: VapulaProject, results selection: [AnalysisResult]? = nil, figures: [ReportFigure] = [],
    software: ReportSoftware = .current
  ) throws -> Data {
    try Task.checkCancellation()
    let results = selection ?? project.results
    guard results.allSatisfy({ $0.metrics.values.allSatisfy(\.isFinite) }) else {
      throw VapulaError.invalid(
        "El informe contiene métricas no finitas. Revisa los resultados antes de exportar.")
    }
    guard
      results.allSatisfy({ result in
        project.results.contains(result)
      })
    else {
      throw VapulaError.invalid("El resultado seleccionado no pertenece a este proyecto.")
    }
    let renderer = try Renderer(projectName: project.name, software: software)
    guard figures.allSatisfy({ figure in project.datasets.contains { $0.id == figure.datasetID } }) else {
      throw VapulaError.invalid("Un gráfico no pertenece a las versiones del informe.")
    }
    try renderer.paragraph("VAPULA", style: .title)
    try renderer.paragraph("Data & Statistical Laboratory", style: .subtitle)
    try renderer.paragraph(project.name, style: .section)
    try renderer.paragraph(
      "Informe de resultados · \(results.count) análisis\nCreado por Sebastián Pastén F.",
      style: .body)
    try renderer.paragraph(
      "Proyecto: \(project.id.uuidString) · esquema \(project.schemaVersion)", style: .small)
    try renderer.paragraph("Exportado con \(software.label) · DuckDB 1.1.3", style: .small)
    try renderer.paragraph(
      "Los resultados describen los datos y procedimientos declarados. Una asociación no establece causalidad; una detección de calidad no confirma un error.",
      style: .note)

    let versions = relevantVersions(project: project, selection: selection)
    let sourceIDs = Set(versions.map(\.sourceID))
    let sources =
      selection == nil ? project.sources : project.sources.filter { sourceIDs.contains($0.id) }
    try renderer.paragraph("Fuentes y procedencia", style: .section)
    if sources.isEmpty {
      try renderer.paragraph("No hay fuentes incorporadas para esta selección.", style: .body)
    }
    for source in sources {
      try Task.checkCancellation()
      try renderer.paragraph(source.name, style: .subheading)
      try renderer.paragraph(
        "\(source.format.uppercased()) · \(source.bytes) bytes · fuente \(source.id.uuidString)",
        style: .small)
      try renderer.paragraph("SHA-256: \(source.sha256)", style: .code)
      try renderer.paragraph(
        "Importada: \(timestamp(source.importedAt)). Delimitador: \(source.options.delimiter == "auto" ? "automático" : source.options.delimiter). Decimal: \(source.options.decimalSeparator). Cabeceras: \(source.options.header ? "sí" : "no"). Todo como texto: \(source.options.allText ? "sí" : "no").",
        style: .small)
    }
    try renderer.paragraph("Versiones de datos", style: .section)
    if versions.isEmpty {
      try renderer.paragraph("No hay versiones de datos registradas.", style: .body)
    }
    for version in versions {
      try Task.checkCancellation()
      try renderer.paragraph("\(version.name) · \(version.rowCount) filas", style: .subheading)
      try renderer.paragraph("Versión: \(version.id.uuidString)", style: .code)
      try renderer.paragraph(
        "Origen: \(version.sourceID.uuidString)\nVersión anterior: \(version.parentID?.uuidString ?? "ninguna")\nOperación: \(version.operation?.summary ?? "Importación")",
        style: .small)
    }

    try renderer.paragraph("Resultados estadísticos", style: .section)
    if results.isEmpty {
      try renderer.paragraph("No hay análisis incluidos en este informe.", style: .body)
    }
    for (index, result) in results.enumerated() {
      try Task.checkCancellation()
      try renderer.paragraph(
        "\(index + 1). \(result.specification.method.title)", style: .analysis)
      try renderer.paragraph(result.specification.variableSummary, style: .body)
      try renderer.paragraph(
        "Observaciones válidas: \(result.validCount) · excluidas: \(result.excludedCount) · alfa: \(number(result.specification.alpha))\nCalculado: \(timestamp(result.createdAt))",
        style: .small)
      try renderer.paragraph(
        "Resultado: \(result.id.uuidString)\nDataset: \(result.datasetID.uuidString)", style: .code)
      try renderer.metricTable(result.metrics)
      try renderer.paragraph("Procedimiento", style: .subheading)
      try renderer.paragraph(result.procedure, style: .body)
      if result.warnings.isEmpty == false {
        try renderer.paragraph("Supuestos y advertencias", style: .subheading)
        for warning in result.warnings {
          try renderer.paragraph("- \(warning)", style: .note)
        }
      }
      renderer.addGap(14)
    }
    if !figures.isEmpty {
      for (index, figure) in figures.enumerated() {
        try renderer.figure(figure, sectionTitle: index == 0 ? "Gráficos" : nil)
      }
    }
    let versionIDs = Set(versions.map(\.id))
    let findings = project.findings.filter { selection == nil || versionIDs.contains($0.datasetID) }
    if findings.isEmpty == false {
      try renderer.paragraph("Hallazgos de calidad", style: .section)
      for finding in findings {
        try Task.checkCancellation()
        try renderer.paragraph(
          "\(finding.rule.label) · \(finding.affectedRows) filas candidatas\nDataset: \(finding.datasetID.uuidString)\n\(finding.note)",
          style: .small)
      }
    }
    return try renderer.finish()
  }

  private static func relevantVersions(
    project: VapulaProject, selection: [AnalysisResult]?
  ) -> [DatasetVersion] {
    guard let selection else { return project.datasets }
    let byID = Dictionary(
      project.datasets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    var included = Set<UUID>()
    for result in selection {
      var next: UUID? = result.datasetID
      while let id = next, included.insert(id).inserted {
        next = byID[id]?.parentID
      }
    }
    return project.datasets.filter { included.contains($0.id) }
  }

  private static func timestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_CL")
    formatter.timeZone = TimeZone(identifier: "America/Santiago")
    formatter.dateFormat = "dd MMM yyyy, HH:mm zzz"
    return formatter.string(from: date)
  }

  private static func number(_ value: Double) -> String {
    String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)
  }

  private enum Style {
    case title, subtitle, section, analysis, subheading, body, small, code, note
    var size: CGFloat {
      switch self {
      case .title: 31
      case .subtitle: 11
      case .section: 17
      case .analysis: 15
      case .subheading: 11
      case .body, .note: 10
      case .small: 9
      case .code: 8
      }
    }
    var fontName: String {
      switch self {
      case .title, .section, .analysis, .subheading: "HelveticaNeue-Bold"
      case .code: "Menlo-Regular"
      default: "HelveticaNeue"
      }
    }
    var spaceBefore: CGFloat {
      switch self {
      case .section: 17
      case .analysis: 14
      case .subheading: 7
      default: 0
      }
    }
    var spaceAfter: CGFloat {
      switch self {
      case .title: 5
      case .subtitle: 11
      case .section, .analysis: 10
      default: 7
      }
    }
    var minimumFollowingSpace: CGFloat {
      switch self {
      case .section, .analysis: 44
      case .subheading: 24
      default: 0
      }
    }
    var gray: CGFloat {
      switch self {
      case .small, .subtitle, .code: 0.32
      case .note: 0.22
      default: 0.05
      }
    }
  }

  private final class Renderer {
    private let data = NSMutableData()
    private let context: CGContext
    private let projectName: String
    private let page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    private let margin: CGFloat = 48
    private let bottom: CGFloat = 61
    private var cursor: CGFloat = 0
    private var pageNumber = 0
    private var finished = false
    private var contentWidth: CGFloat { page.width - 2 * margin }
    private var contentTop: CGFloat { page.height - 87 }

    init(projectName: String, software: ReportSoftware) throws {
      self.projectName = projectName
      guard let consumer = CGDataConsumer(data: data as CFMutableData),
        let context = CGContext(
          consumer: consumer, mediaBox: nil,
          [
            kCGPDFContextTitle: "VAPULA - \(projectName)",
            kCGPDFContextAuthor: "Sebastián Pastén F.",
            kCGPDFContextCreator: "\(software.label) - native CoreGraphics/CoreText",
          ] as CFDictionary)
      else { throw VapulaError.invalid("No se pudo crear el documento PDF.") }
      self.context = context
      beginPage()
    }

    private func beginPage() {
      var mediaBox = page
      let boxData = Data(bytes: &mediaBox, count: MemoryLayout<CGRect>.size)
      context.beginPDFPage([kCGPDFContextMediaBox: boxData as CFData] as CFDictionary)
      pageNumber += 1
      cursor = contentTop
      line("VAPULA", x: margin, y: page.height - 43, style: .subheading)
      let header = projectName.count > 65 ? String(projectName.prefix(64)) + "…" : projectName
      line(header, x: margin, y: page.height - 60, style: .small, maxWidth: contentWidth)
      context.setStrokeColor(CGColor(gray: 0.75, alpha: 1))
      context.setLineWidth(0.5)
      context.move(to: CGPoint(x: margin, y: page.height - 71))
      context.addLine(to: CGPoint(x: page.width - margin, y: page.height - 71))
      context.strokePath()
    }

    private func endPage() {
      context.setStrokeColor(CGColor(gray: 0.8, alpha: 1))
      context.setLineWidth(0.5)
      context.move(to: CGPoint(x: margin, y: 46))
      context.addLine(to: CGPoint(x: page.width - margin, y: 46))
      context.strokePath()
      line("Procesamiento local · Creado por Sebastián Pastén F.", x: margin, y: 30, style: .code)
      let label = "Página \(pageNumber)"
      let attributed = attributed(label, style: .code)
      let ctLine = CTLineCreateWithAttributedString(attributed)
      let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, nil, nil))
      context.textPosition = CGPoint(x: page.width - margin - width, y: 30)
      CTLineDraw(ctLine, context)
      context.endPDFPage()
    }

    private func newPage() {
      endPage()
      beginPage()
    }

    private func attributed(_ text: String, style: Style) -> NSAttributedString {
      let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\0", with: "")
      let font = CTFontCreateWithName(style.fontName as CFString, style.size, nil)
      let color = CGColor(gray: style.gray, alpha: 1)
      var lineSpacing: CGFloat = 3
      let paragraphStyle = withUnsafePointer(to: &lineSpacing) { pointer in
        var setting = CTParagraphStyleSetting(
          spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: pointer)
        return CTParagraphStyleCreate(&setting, 1)
      }
      return NSAttributedString(
        string: normalized,
        attributes: [
          NSAttributedString.Key(kCTFontAttributeName as String): font,
          NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
          NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyle,
        ])
    }

    private func line(
      _ text: String, x: CGFloat, y: CGFloat, style: Style, maxWidth: CGFloat? = nil
    ) {
      context.textMatrix = .identity
      context.textPosition = CGPoint(x: x, y: y)
      let original = CTLineCreateWithAttributedString(attributed(text, style: style))
      let rendered: CTLine
      if let maxWidth {
        let token = CTLineCreateWithAttributedString(attributed("…", style: style))
        rendered = CTLineCreateTruncatedLine(original, Double(maxWidth), .end, token) ?? original
      } else {
        rendered = original
      }
      CTLineDraw(rendered, context)
    }

    private func height(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
      let framesetter = CTFramesetterCreateWithAttributedString(text)
      return ceil(
        CTFramesetterSuggestFrameSizeWithConstraints(
          framesetter, CFRange(location: 0, length: text.length), nil,
          CGSize(width: width, height: 100_000), nil
        ).height) + 1
    }

    func addGap(_ height: CGFloat) { cursor -= height }

    func paragraph(_ text: String, style: Style) throws {
      guard text.isEmpty == false else { return }
      let attributed = attributed(text, style: style)
      let framesetter = CTFramesetterCreateWithAttributedString(attributed)
      let desired = height(attributed, width: contentWidth)
      let required = min(desired, style.size * 3) + style.minimumFollowingSpace + style.spaceBefore
      if cursor - required < bottom { newPage() }
      cursor -= style.spaceBefore
      var offset = 0
      while offset < attributed.length {
        try Task.checkCancellation()
        let available = cursor - bottom
        if available < style.size + 6 {
          newPage()
          continue
        }
        let rectangle = CGRect(x: margin, y: bottom, width: contentWidth, height: available)
        let frame = CTFramesetterCreateFrame(
          framesetter, CFRange(location: offset, length: attributed.length - offset),
          CGPath(rect: rectangle, transform: nil), nil)
        let visible = CTFrameGetVisibleStringRange(frame)
        guard visible.length > 0 else {
          throw VapulaError.invalid("No se pudo paginar un bloque del informe PDF.")
        }
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
        let lines = CTFrameGetLines(frame) as NSArray
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        if let last = origins.last {
          let font = CTFontCreateWithName(style.fontName as CFString, style.size, nil)
          cursor = bottom + last.y - CTFontGetDescent(font) - style.spaceAfter
        } else {
          cursor = bottom
        }
        offset += visible.length
        if offset < attributed.length { newPage() }
      }
    }

    func metricTable(_ metrics: [String: Double]) throws {
      guard metrics.isEmpty == false else { return }
      let valueWidth: CGFloat = 142
      let gap: CGFloat = 18
      let keyWidth = contentWidth - valueWidth - gap
      func tableHeader() {
        if cursor - 30 < bottom { newPage() }
        context.setFillColor(CGColor(gray: 0.94, alpha: 1))
        context.fill(CGRect(x: margin, y: cursor - 25, width: contentWidth, height: 25))
        line("Estadístico", x: margin + 8, y: cursor - 17, style: .subheading)
        line("Valor", x: margin + keyWidth + gap + 8, y: cursor - 17, style: .subheading)
        cursor -= 31
      }
      tableHeader()
      for key in MetricPresentation.visibleKeys(metrics) {
        try Task.checkCancellation()
        guard let value = metrics[key] else { continue }
        let keyText = attributed(MetricPresentation.title(key), style: .small)
        let valueText = attributed(PDFReport.number(value), style: .code)
        let rowHeight = max(22, height(keyText, width: keyWidth - 16) + 10)
        guard rowHeight <= contentTop - bottom - 35 else {
          throw VapulaError.invalid("El nombre de una métrica excede el espacio de una página PDF.")
        }
        if cursor - rowHeight < bottom {
          newPage()
          tableHeader()
        }
        drawCell(keyText, x: margin + 8, width: keyWidth - 16, height: rowHeight)
        drawCell(
          valueText, x: margin + keyWidth + gap + 8, width: valueWidth - 16, height: rowHeight)
        cursor -= rowHeight
        context.setStrokeColor(CGColor(gray: 0.86, alpha: 1))
        context.setLineWidth(0.4)
        context.move(to: CGPoint(x: margin, y: cursor))
        context.addLine(to: CGPoint(x: page.width - margin, y: cursor))
        context.strokePath()
      }
      cursor -= 9
    }

    private func drawCell(_ text: NSAttributedString, x: CGFloat, width: CGFloat, height: CGFloat) {
      let rectangle = CGRect(x: x, y: cursor - height, width: width, height: height - 4)
      let frame = CTFramesetterCreateFrame(
        CTFramesetterCreateWithAttributedString(text), CFRange(location: 0, length: text.length),
        CGPath(rect: rectangle, transform: nil), nil)
      context.textMatrix = .identity
      CTFrameDraw(frame, context)
    }

    func figure(_ figure: ReportFigure, sectionTitle: String?) throws {
      try Task.checkCancellation()
      let data = figure.png
      guard data.count <= 20_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width > 0, image.height > 0,
        image.width <= 10_000, image.height <= 10_000 else { throw VapulaError.invalid("No se pudo incorporar el gráfico al PDF.") }
      let imageHeight = min(310, contentWidth * CGFloat(image.height) / CGFloat(image.width))
      let width = imageHeight * CGFloat(image.width) / CGFloat(image.height)
      let caption = "Versión de datos: \(figure.datasetID.uuidString)\n\(figure.caption)"
      func blockHeight(_ text: String, _ style: Style) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        return height(attributed(text, style: style), width: contentWidth) + style.spaceBefore + style.spaceAfter + 4
      }
      let required = blockHeight(figure.title, .analysis) + blockHeight(caption, .small)
        + imageHeight + 16 + (sectionTitle.map { blockHeight($0, .section) } ?? 0)
      // Keep bounded app figures with their title/caption. Oversized external text
      // still uses normal paragraph pagination instead of clipping or dropping it.
      if required <= contentTop - bottom, cursor - required < bottom { newPage() }
      if let sectionTitle { try paragraph(sectionTitle, style: .section) }
      try paragraph(figure.title, style: .analysis)
      try paragraph(caption, style: .small)
      if cursor - imageHeight < bottom { newPage() }
      context.saveGState()
      context.interpolationQuality = .high
      context.draw(image, in: CGRect(x: margin + (contentWidth - width) / 2, y: cursor - imageHeight, width: width, height: imageHeight))
      context.restoreGState()
      cursor -= imageHeight + 16
    }
    func finish() throws -> Data {
      guard finished == false else { throw VapulaError.invalid("El PDF ya fue finalizado.") }
      finished = true
      endPage()
      context.closePDF()
      return data as Data
    }
  }
}
