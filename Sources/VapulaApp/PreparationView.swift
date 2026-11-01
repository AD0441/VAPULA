import SwiftUI
import VapulaCore

struct PreparationView: View {
  let workspace: Workspace
  let dataset: DatasetVersion
  var initial: Transformation? = nil
  var onApply: ((Transformation) -> Void)? = nil
  var onAudit: (([QualityRule]) -> Void)? = nil
  var compact = false
  var purpose = PreparationPurpose.all
  var initialRules: [QualityRule]? = nil
  @State private var column = ""
  @State private var action = "filter"
  @State private var comparison = Comparison.equal
  @State private var value = ""
  @State private var newName = ""
  @State private var physicalType = PhysicalType.number
  @State private var arithmetic = Arithmetic.multiply
  @State private var aggregate = Aggregate.mean
  @State private var group = ""
  @State private var selectedColumns = Set<String>()
  @State private var duplicateKeys = Set<String>()
  @State private var lower = ""
  @State private var upper = ""
  @State private var rangeEnabled = false
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if purpose != .quality {
        if !compact { Text("Preparación reproducible").font(.title2.weight(.semibold)) }
        Text(
          "Cada operación crea una versión. Puedes volver a cualquier versión desde el selector superior."
        ).foregroundStyle(.secondary)
        Form {
          Picker("Operación", selection: $action) {
            Text("Filtrar").tag("filter")
            Text("Seleccionar columnas").tag("select")
            Text("Renombrar").tag("rename")
            Text("Cambiar tipo").tag("cast")
            Text("Columna derivada").tag("derive")
            Text("Ordenar").tag("sort")
            Text("Agrupar y agregar").tag("aggregate")
          }
          Picker("Columna", selection: $column) {
            ForEach(dataset.columns) { Text($0.name).tag($0.name) }
          }
          if action == "filter" {
            Picker("Condición", selection: $comparison) {
              ForEach(Comparison.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if comparison != .isNull { TextField("Valor", text: $value) }
          }
          if action == "rename" || action == "derive" { TextField("Nuevo nombre", text: $newName) }
          if action == "cast" {
            Picker("Tipo", selection: $physicalType) {
              ForEach(PhysicalType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Text(
              "Los valores incompatibles se convierten en NULL. Revisa el perfil de la nueva versión antes de continuar."
            ).font(.caption).foregroundStyle(.secondary)
          }
          if action == "derive" {
            Picker("Aritmética", selection: $arithmetic) {
              ForEach(Arithmetic.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField("Constante numérica (punto decimal)", text: $value)
          }
          if action == "sort" {
            Text("Orden ascendente, ausentes al final.").foregroundStyle(.secondary)
          }
          if action == "select" {
            ColumnChecklist(columns: dataset.columns, selected: $selectedColumns)
          }
          if action == "aggregate" {
            Picker("Agrupar por", selection: $group) {
              ForEach(dataset.columns) { Text($0.name).tag($0.name) }
            }
            Picker("Agregación", selection: $aggregate) {
              ForEach(Aggregate.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
          }
        }.formStyle(.grouped)
        Button("Crear versión", action: apply).buttonStyle(.borderedProminent).tint(.primary)
        }
        if purpose != .transform {
        Divider()
        Text("Calidad de datos").font(.title2.weight(.semibold))
        Text(
          "Nulos, valores no finitos y candidatos IQR se revisan en todas las columnas pertinentes. Define claves para duplicados o un rango adicional."
        ).foregroundStyle(.secondary)
        DisclosureGroup("Claves de duplicados") {
          ColumnChecklist(columns: dataset.columns, selected: $duplicateKeys).padding(.top, 8)
        }
        Toggle("Comprobar rango de la columna seleccionada", isOn: $rangeEnabled)
        if rangeEnabled {
          HStack {
            Text(column)
            TextField("Mínimo", text: $lower)
            TextField("Máximo", text: $upper)
          }.textFieldStyle(.roundedBorder)
        }
        Button("Revisar calidad") {
          if let onAudit {
            var rules = dataset.columns.map { QualityRule.missing($0.name) }
            rules += dataset.columns.filter(\.isNumeric).flatMap { [QualityRule.nonFinite($0.name), .outlier($0.name)] }
            rules += dataset.columns.filter { $0.physicalType == "VARCHAR" }.map { QualityRule.blank($0.name) }
            if !duplicateKeys.isEmpty { rules.append(.duplicates(duplicateKeys.sorted())) }
            if rangeEnabled, let low = Double(lower), let high = Double(upper) { rules.append(.range(column, low, high)) }
            onAudit(rules)
          } else {
            workspace.audit(keys: duplicateKeys.sorted(), rangeColumn: rangeEnabled ? column : nil,
              lower: Double(lower), upper: Double(upper))
          }
        }.disabled(rangeEnabled && (Double(lower) == nil || Double(upper) == nil))
        if workspace.findings.isEmpty == false {
          ForEach(workspace.findings) { finding in
            HStack {
              VStack(alignment: .leading, spacing: 5) {
                Text(finding.rule.label).font(.headline)
                Text(
                  "\(finding.affectedRows) filas candidatas · una detección no confirma un error"
                ).foregroundStyle(.secondary).font(.caption)
              }
              Spacer()
              Button("Ver evidencia") { workspace.showEvidence(finding) }.disabled(
                finding.affectedRows == 0)
            }
          }
        }
        }
      }.padding(compact ? 16 : 28).frame(maxWidth: compact ? .infinity : 900, alignment: .leading)
    }.disabled(workspace.busy).task {
      column = dataset.columns.first?.name ?? ""
      group = column
      selectedColumns = Set(dataset.columns.map(\.name))
      switch initial {
      case .filter(let name, let op, let input): action = "filter"; column = name; comparison = op; value = input
      case .select(let names): action = "select"; selectedColumns = Set(names)
      case .rename(let name, let output): action = "rename"; column = name; newName = output
      case .cast(let name, let type): action = "cast"; column = name; physicalType = type
      case .derive(let name, let op, let constant, let output): action = "derive"; column = name; arithmetic = op; value = String(constant); newName = output
      case .sort(let name, _): action = "sort"; column = name
      case .aggregate(let key, let name, let function): action = "aggregate"; group = key; column = name; aggregate = function
      default: break
      }
      for rule in initialRules ?? [] {
        switch rule {
        case .duplicates(let keys): duplicateKeys = Set(keys)
        case .range(let name, let low, let high): column = name; lower = String(low); upper = String(high); rangeEnabled = true
        default: break
        }
      }
    }
  }
  private func apply() {
    let operation: Transformation
    switch action {
    case "select":
      operation = .select(
        columns: dataset.columns.map(\.name).filter { selectedColumns.contains($0) })
    case "rename": operation = .rename(column: column, name: newName)
    case "cast": operation = .cast(column: column, type: physicalType)
    case "derive":
      guard let number = Double(value), number.isFinite else {
        workspace.error = "La constante debe ser numérica (usa punto decimal)."
        return
      }
      operation = .derive(column: column, operation: arithmetic, value: number, name: newName)
    case "sort": operation = .sort(column: column, ascending: true)
    case "aggregate": operation = .aggregate(group: group, column: column, function: aggregate)
    default: operation = .filter(column: column, comparison: comparison, value: value)
    }
    if let onApply { onApply(operation) } else { workspace.transform(operation) }
  }
}
struct ColumnChecklist: View {
  let columns: [ColumnDefinition]
  @Binding var selected: Set<String>
  var body: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading
    ) {
      ForEach(columns) { c in
        Toggle(
          c.name,
          isOn: Binding(
            get: { selected.contains(c.name) },
            set: { if $0 { selected.insert(c.name) } else { selected.remove(c.name) } }))
      }
    }
  }
}

enum PreparationPurpose { case all, transform, quality }
