import Foundation

/// Extracts bounded reading context, never the SQL query/stack embedded in an engine error.
public enum ImportDiagnostic {
  public static func message(_ detail: String, filename: String, options: ImportOptions) -> String {
    let lower = detail.lowercased()
    var lines = ["No se pudo leer «\(filename)». No se ha añadido una versión incompleta."]
    if lower.contains("only local csv") {
      lines.append("Selecciona un archivo CSV, TSV o Parquet local. Para otros formatos, exporta primero una tabla compatible desde la aplicación de origen.")
    } else if lower.contains("utf-8") || lower.contains("unicode") {
      lines.append("El archivo debe estar en UTF-8, con o sin BOM. Convierte su codificación y vuelve a seleccionarlo.")
    } else if lower.contains("wildcard") {
      lines.append("La ruta contiene caracteres de comodín (* ? [ ] { }). Renombra el archivo o su carpeta y vuelve a seleccionarlo.")
    } else if lower.contains("256 columns") || lower.contains("256 columnas") {
      lines.append("El archivo supera el máximo de 256 columnas. Divide la tabla antes de importarla.")
    } else if lower.contains("source changed") {
      lines.append("La fuente cambió durante la lectura. Cierra la aplicación que la modifica o importa una copia estable.")
    } else if lower.contains("permission") || lower.contains("denied") || lower.contains("no such file") {
      lines.append("Comprueba que el archivo siga en esa ubicación y que tengas permiso para leerlo.")
    } else if lower.contains("parquet") {
      lines.append("No se pudo interpretar el archivo Parquet. Comprueba que esté completo y ábrelo con la herramienta que lo generó.")
    } else {
      if let line = capture(#"(?:CSV Error on Line|Line Number|line)\s*:?\s*(\d+)"#, in: detail) {
        lines.append("Fila informada por el lector: \(line).")
      }
      if let column = capture(#"(?:column name|column)\s*:?\s*[\"']([^\"'\n]{1,120})[\"']"#, in: detail) {
        lines.append("Columna: \(column).")
      }
      if let sample = capture(#"Original Line:\s*([^\n]{1,240})"#, in: detail) {
        lines.append("Ejemplo de la fila: \(sample)")
      }
      if lines.count == 1 {
        lines.append("El lector no informó una fila o columna concreta. Revisa la estructura del archivo en la vista previa.")
      }
      lines.append("Revisa delimitador, cabecera, separador decimal, formato de fecha y comillas en la vista previa.")
      lines.append(options.allText
        ? "La lectura ya está configurada como texto: revisa que todas las filas tengan la misma estructura."
        : "Puedes probar «Leer todo como texto», revisar los valores y convertir después con vista previa del impacto.")
    }
    return lines.joined(separator: "\n")
  }

  private static func capture(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      let range = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[range])
  }
}
