import Testing
import VapulaCore

struct ImportDiagnosticTests {
  @Test func diagnosticKeepsReadingContextAndOmitsInternalQueries() {
    let raw = "Conversion Error: column \"edad\"\nCSV Error on Line: 8\nOriginal Line: 7,no,grupo-A\nLINE 1: CREATE TABLE v_private AS SELECT secret FROM internal;\nStack trace: engine.cpp"
    let message = ImportDiagnostic.message(raw, filename: "ejemplo.csv", options: ImportOptions())
    #expect(message.contains("8") && message.contains("edad") && message.contains("7,no,grupo-A"))
    #expect(message.contains("Leer todo como texto"))
    #expect(message.contains("CREATE TABLE") == false && message.contains("engine.cpp") == false)
  }
  @Test(arguments: [("UTF-8", "Convierte"), ("Wildcard characters", "Renombra"), ("at most 256 columns", "Divide"), ("Permission denied", "permiso"), ("Parquet footer", "completo")])
  func supportedFailureCategoriesHaveActionableMessages(input: (String, String)) {
    let (detail, action) = input
    let message = ImportDiagnostic.message(detail, filename: "datos.csv", options: ImportOptions())
    #expect(message.contains("datos.csv"))
    #expect(message.contains("No se ha añadido una versión incompleta"))
    #expect(message.contains(action))
  }
}
