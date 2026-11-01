import SwiftUI
import VapulaCore

struct DataStudioView: View {
  @Bindable var workspace: Workspace
  let dataset: DatasetVersion
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        TextField("Buscar en todas las columnas", text: $workspace.search).textFieldStyle(
          .roundedBorder
        ).onSubmit { workspace.reloadPage() }.frame(maxWidth: 360)
        Button("Buscar", action: workspace.reloadPage)
        Spacer()
        Button("Perfil completo", action: workspace.profile)
        Menu("Exportar") {
          Button("CSV…") { workspace.exportData(parquet: false) }
          Button("Parquet…") { workspace.exportData(parquet: true) }
          Button("Informe Markdown…") { workspace.exportReport(csv: false) }
        }
      }.padding(16).disabled(workspace.busy)
      DataGrid(columns: dataset.columns, rows: workspace.page.rows, onSort: workspace.sort)
      HStack {
        Text("\(workspace.page.matchingRows) coincidencias")
        Spacer()
        Button("Anterior") { workspace.turnPage(-1) }.disabled(
          workspace.offset == 0 || workspace.busy)
        Text("\(workspace.offset+1)–\(workspace.offset+workspace.page.rows.count)")
          .monospacedDigit()
        Button("Siguiente") { workspace.turnPage(1) }.disabled(
          workspace.offset + 100 >= workspace.page.matchingRows || workspace.busy)
      }.font(.callout).padding(14)
      if workspace.profiles.isEmpty == false {
        Divider()
        ScrollView(.horizontal) {
          HStack(alignment: .top, spacing: 28) {
            ForEach(workspace.profiles) { p in
              VStack(alignment: .leading, spacing: 7) {
                Text(p.column.name).font(.headline)
                Text(p.column.physicalType).font(.caption).foregroundStyle(.secondary)
                Text("Válidos: \(p.valid) · ausentes/no finitos: \(p.missing)")
                Text("Distintos: \(p.distinct)")
                if let mean = p.mean {
                  Text("Media: \(mean.formatted(.number.precision(.significantDigits(6))))")
                }
                if let median = p.median {
                  Text("Mediana: \(median.formatted(.number.precision(.significantDigits(6))))")
                }
                if let sd = p.sd {
                  Text("DE muestral: \(sd.formatted(.number.precision(.significantDigits(6))))")
                }
                Text("Min: \(p.minimum ?? "—") · Max: \(p.maximum ?? "—")")
              }.font(.caption).textSelection(.enabled)
            }
          }.padding(18)
        }.frame(height: 190)
      }
    }
  }
}
struct ImportView: View {
  @Bindable var workspace: Workspace
  @State private var options = ImportOptions()
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Importar datos").font(.title2.weight(.semibold))
      Text(workspace.importURL?.lastPathComponent ?? "").font(.headline)
      Text(
        "Los datos se incorporan a la base del proyecto; no se conserva una segunda copia del archivo original. Se requiere espacio para los datos, versiones y temporales. La fuente externa permanece intacta."
      ).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      HStack(alignment: .top, spacing: 24) {
        Picker("Delimitador", selection: $options.delimiter) {
          Text("Automático").tag("auto")
          Text("Coma").tag(",")
          Text("Punto y coma").tag(";")
          Text("Tabulación").tag("\t")
          Text("Barra vertical").tag("|")
        }.frame(width: 220)
        Picker("Decimal", selection: $options.decimalSeparator) {
          Text("Punto").tag(".")
          Text("Coma").tag(",")
        }.frame(width: 150)
        Toggle("Cabeceras", isOn: $options.header)
        Toggle("Todo como texto", isOn: $options.allText)
      }.disabled(workspace.busy || workspace.importURL?.pathExtension.lowercased() == "parquet")
      TextField("Formato de fecha opcional, p. ej. %d/%m/%Y", text: $options.dateFormat)
        .textFieldStyle(.roundedBorder).disabled(workspace.busy)
      HStack {
        Button("Actualizar vista previa") { workspace.previewImport(options) }.disabled(
          workspace.busy)
        Text("Hasta 20 filas · tipos detectados · UTF-8 con o sin BOM").font(.caption)
          .foregroundStyle(.secondary)
      }
      if let error = workspace.previewError {
        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.primary)
          .textSelection(.enabled)
      }
      DataGrid(columns: workspace.previewColumns, rows: workspace.previewRows).frame(minHeight: 180)
      HStack {
        Button("Cancelar") { workspace.showImport = false }.keyboardShortcut(.cancelAction)
          .disabled(workspace.busy)
        Spacer()
        if workspace.busy {
          ProgressView().controlSize(.small)
          Button("Detener", action: workspace.cancel)
        }
        Button("Importar") { workspace.confirmImport(options) }.buttonStyle(.borderedProminent)
          .tint(.primary).disabled(workspace.busy || workspace.previewColumns.isEmpty)
      }
    }.padding(28).frame(width: 900, height: 620).task { workspace.previewImport(options) }
  }
}
