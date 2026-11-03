import SwiftUI
import VapulaCore

enum DataEditKind: Equatable { case cell, row, column, removeRows }
struct DataEditRequest: Identifiable {
  let id = UUID()
  let kind: DataEditKind
  let dataset: DatasetVersion
  var row: DataRow?
  var column: String?
  var rows: [DataRow] = []
}
struct DataEditingView: View {
  let workspace: Workspace
  let request: DataEditRequest
  @State private var column = ""
  @State private var value = ""
  @State private var isNull = false
  @State private var newName = ""
  @State private var type = PhysicalType.text
  @State private var values: [String: String] = [:]
  @State private var emptyAsNull = true
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text(T(title)).font(.title2.weight(.semibold))
      Text(L("Se creará una versión nueva de \(request.dataset.name). La entrada y las fuentes originales se conservan.")).foregroundStyle(.secondary).font(.callout)
      ScrollView {
        Form {
          switch request.kind {
          case .cell:
            Picker(L("Columna"), selection: $column) { ForEach(request.dataset.columns) { Text($0.name).tag($0.name) } }
            Text(L("Valor anterior: \(oldValue ?? "NULL")")).textSelection(.enabled).foregroundStyle(.secondary)
            Toggle(L("Dejar como NULL"), isOn: $isNull)
            if !isNull { TextField(L("Nuevo valor"), text: $value).textFieldStyle(.roundedBorder) }
          case .column:
            TextField(L("Nombre de columna"), text: $newName)
            Picker(L("Tipo"), selection: $type) { ForEach(PhysicalType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Toggle(L("Inicializar como NULL"), isOn: $isNull)
            if !isNull { TextField(L("Valor inicial"), text: $value) }
          case .row:
            Toggle(L("Campos vacíos como NULL"), isOn: $emptyAsNull)
            ForEach(request.dataset.columns) { definition in
              TextField(definition.name, text: Binding(get: { values[definition.name] ?? "" }, set: { values[definition.name] = $0 }))
                .help(definition.physicalType)
            }
          case .removeRows:
            Text(L("\(request.rows.count) filas seleccionadas quedarán fuera de la nueva versión."))
            Text(L("Las filas se identifican dentro de esta versión, incluso si la tabla estaba buscada u ordenada.")).foregroundStyle(.secondary)
          }
        }.formStyle(.grouped)
      }.frame(minHeight: 150, maxHeight: 350)
      HStack {
        Button(L("Cancelar")) { workspace.editRequest = nil }.keyboardShortcut(.cancelAction)
        Spacer()
        Button(L("Crear versión"), action: apply).buttonStyle(.borderedProminent)
          .disabled(workspace.busy || (request.kind == .column && newName.isEmpty))
      }
    }.padding(24).frame(width: 560).onAppear {
      column = request.column ?? request.dataset.columns.first?.name ?? ""
      value = oldValue ?? ""; isNull = request.kind == .column || oldValue == nil
    }.onChange(of: column) { value = oldValue ?? ""; isNull = oldValue == nil }
  }
  private var title: String {
    switch request.kind { case .cell: "Corregir una celda"; case .row: "Añadir una fila"; case .column: "Añadir una columna"; case .removeRows: "Retirar filas seleccionadas" }
  }
  private var oldValue: String? {
    guard let index = request.dataset.columns.firstIndex(where: { $0.name == column }), let row = request.row, row.cells.indices.contains(index) else { return nil }
    return row.cells[index]
  }
  private func apply() {
    let operation: Transformation
    switch request.kind {
    case .cell:
      guard let id = request.row?.sourceRowID else { workspace.error = L("No se dispone del identificador de esa fila. Si existe una columna rowid, renómbrala antes de editar."); return }
      operation = .editCell(rowID: id, column: column, value: isNull ? nil : value)
    case .column: operation = .addColumn(name: newName, type: type, value: isNull ? nil : value)
    case .row:
      let fields = Dictionary(uniqueKeysWithValues: request.dataset.columns.map { definition in
        let text = values[definition.name] ?? ""
        return (definition.name, emptyAsNull && text.isEmpty ? nil : Optional(text))
      })
      operation = .appendRow(values: fields)
    case .removeRows:
      let ids = request.rows.compactMap(\.sourceRowID)
      guard ids.count == request.rows.count else { workspace.error = L("No se pudo identificar una fila seleccionada."); return }
      operation = .removeRows(rowIDs: ids)
    }
    workspace.applyDataEdit(operation, datasetID: request.dataset.id)
  }
}
