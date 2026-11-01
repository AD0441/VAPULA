import Foundation
import VapulaCore

public enum Reports {
  static func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
  }
  public static func markdown(
    _ project: VapulaProject, profiles: [ColumnProfile] = [], profileDatasetID: UUID? = nil
  ) -> String {
    var s =
      "# VAPULA — \(escape(project.name))\n\nData & Statistical Laboratory · Creado por Sebastián Pastén F.\n\nProject: `\(project.id)` · schema \(project.schemaVersion) · DuckDB 1.1.3 · VAPULA 0.1 development\n\n"
    s += "## Sources\n\n| Source | Bytes | SHA-256 |\n|---|---:|---|\n"
    for source in project.sources {
      s += "| \(escape(source.name)) | \(source.bytes) | `\(source.sha256)` |\n"
    }
    s += "\n## Dataset versions\n\n"
    for v in project.datasets {
      s +=
        "- `\(v.id)` · \(escape(v.name)) · \(v.rowCount) rows · source `\(v.sourceID)` · parent \(v.parentID?.uuidString ?? "none") · \(escape(v.operation?.summary ?? "Import"))\n"
    }
    if profiles.isEmpty == false, let profileDatasetID {
      s +=
        "\n## Profile dataset `\(profileDatasetID)`\n\n| Column | Valid | Missing/non-finite | Distinct | Mean | Median | Sample SD |\n|---|---:|---:|---:|---:|---:|---:|\n"
      for p in profiles {
        s +=
          "| \(escape(p.column.name)) | \(p.valid) | \(p.missing) | \(p.distinct) | \(p.mean.map{String($0)} ?? "—") | \(p.median.map{String($0)} ?? "—") | \(p.sd.map{String($0)} ?? "—") |\n"
      }
    }
    s += "\n## Quality candidates\n\n"
    for f in project.findings {
      s +=
        "- Dataset `\(f.datasetID)` · \(escape(f.rule.label)): \(f.affectedRows) affected rows. \(f.note)\n"
    }
    s += "\n## Analyses\n\n"
    for r in project.results {
      s +=
        "### \(r.specification.method.title)\n\nResult `\(r.id)` · dataset `\(r.datasetID)` · \(r.createdAt.ISO8601Format())\n\nVariables: \(escape(r.specification.variableSummary)). Valid n=\(r.validCount); excluded=\(r.excludedCount); alpha=\(r.specification.alpha).\n\n\(r.procedure)\n\n| Estadístico | Clave | Valor |\n|---|---|---:|\n"
      for key in MetricPresentation.visibleKeys(r.metrics) {
        if let value = r.metrics[key] { s += "| \(escape(MetricPresentation.title(key))) | \(escape(key)) | \(value) |\n" }
      }
      s += "\n" + r.warnings.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
    }
    return s
  }
  public static func csv(_ results: [AnalysisResult]) -> String {
    func cell(_ v: String) -> String {
      "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    var lines = ["result_id,dataset_id,method,valid_n,excluded_n,alpha,metric,value"]
    for r in results {
      for k in r.metrics.keys.sorted() {
        if let value = r.metrics[k] {
          lines.append(
            [
              r.id.uuidString, r.datasetID.uuidString, r.specification.method.rawValue,
              String(r.validCount), String(r.excludedCount), String(r.specification.alpha), k,
              String(value),
            ].map(cell).joined(separator: ","))
        }
      }
    }
    return lines.joined(separator: "\n") + "\n"
  }
  public static func writeNew(_ text: String, to url: URL) throws {
    guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) == false else {
      throw VapulaError.invalid("Choose a new report filename. Existing files are protected.")
    }
    // Exclusive creation protects imported sources and avoids overwrite races.
    try Data(text.utf8).write(to: url, options: .withoutOverwriting)
  }
}
