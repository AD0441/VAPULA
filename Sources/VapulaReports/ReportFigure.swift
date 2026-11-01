import Foundation
import VapulaCore

public struct ReportFigure: Sendable {
  public var title: String
  public var datasetID: UUID
  public var caption: String
  public var png: Data
  public init(title: String, datasetID: UUID, caption: String, png: Data) {
    self.title = title; self.datasetID = datasetID; self.caption = caption; self.png = png
  }
}
extension Reports {
  /// Creates the Markdown and its local figures exclusively; rolls back only files created here.
  public static func writeMarkdown(_ project: VapulaProject, figures: [ReportFigure], to url: URL) throws {
    guard url.isFileURL, !FileManager.default.fileExists(atPath: url.path) else { throw VapulaError.invalid("Elige un nombre nuevo para el informe.") }
    let datasetIDs = Set(project.datasets.map(\.id))
    guard figures.allSatisfy({ datasetIDs.contains($0.datasetID) }) else { throw VapulaError.invalid("El gráfico no pertenece al proyecto.") }
    let base = url.deletingPathExtension().lastPathComponent
    let targets = figures.indices.map { url.deletingLastPathComponent().appendingPathComponent("\(base)-grafico-\($0 + 1).png") }
    guard targets.allSatisfy({ !FileManager.default.fileExists(atPath: $0.path) }) else { throw VapulaError.invalid("Ya existe una imagen del informe. Elige otro nombre.") }
    var created: [URL] = []
    do {
      var text = markdown(project)
      if !figures.isEmpty { text += "\n## Gráficos\n\n" }
      for (figure, target) in zip(figures, targets) {
        try Task.checkCancellation()
        try figure.png.write(to: target, options: .withoutOverwriting); created.append(target)
        let title = figure.title.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "#?()[]"))
        let filename = target.lastPathComponent.addingPercentEncoding(withAllowedCharacters: allowed) ?? target.lastPathComponent
        text += "### \(escape(figure.title))\n\n![\(title)](<\(filename)>)\n\nDataset `\(figure.datasetID)` · \(escape(figure.caption))\n\n"
      }
      try writeNew(text, to: url)
    } catch {
      for target in created { try? FileManager.default.removeItem(at: target) }
      throw error
    }
  }
}
