import SwiftUI
import VapulaCore

struct PreparationView: View {
  let workspace: Workspace
  let dataset: DatasetVersion
  var draftKey: InspectorDraftKey? = nil
  @State private var draftRevision = -1
  @State private var draftBaseline: PreparationDraft?
  var initial: Transformation? = nil
  var onApply: ((Transformation, CastApproval?) -> Void)? = nil
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
  @State private var castImpact: CastImpact?
  @State private var castChecking = false
  @State private var castIssue: String?
  @State private var confirmCast = false
  private var castKey: CastPreviewKey { CastPreviewKey(datasetID: dataset.id, column: column, type: physicalType, active: action == "cast") }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if purpose != .quality {
        if !compact { Text(L("Preparación reproducible")).font(.title2.weight(.semibold)) }
        Text(
          L("Cada operación crea una versión. Puedes volver a cualquier versión desde el selector superior.")
        ).foregroundStyle(.secondary)
        Form {
          Picker(L("Operación"), selection: $action) {
            Text(L("Filtrar")).tag("filter")
            Text(L("Seleccionar columnas")).tag("select")
            Text(L("Renombrar")).tag("rename")
            Text(L("Cambiar tipo")).tag("cast")
            Text(L("Columna derivada")).tag("derive")
            Text(L("Ordenar")).tag("sort")
            Text(L("Agrupar y agregar")).tag("aggregate")
          }
          Picker(L("Columna"), selection: $column) {
            ForEach(dataset.columns) { Text($0.name).tag($0.name) }
          }
          if action == "filter" {
            Picker(L("Condición"), selection: $comparison) {
              ForEach(Comparison.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            if comparison != .isNull { TextField(L("Valor"), text: $value) }
          }
          if action == "rename" || action == "derive" { TextField(L("Nuevo nombre"), text: $newName) }
          if action == "cast" {
            Picker(L("Tipo"), selection: $physicalType) {
              ForEach(PhysicalType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Text(
              L("Revisa cuántos valores pasarían a NULL antes de crear la nueva versión. La entrada se conserva.")
            ).font(.caption).foregroundStyle(.secondary)
            if castChecking { ProgressView(L("Comprobando conversión…")).controlSize(.small) }
            if let castImpact {
              Text(L("Nuevos NULL: \(castImpact.newNulls) · NULL previos: \(castImpact.existingNulls)")).font(.callout.weight(.medium))
              if !castImpact.examples.isEmpty {
                Text(L("Ejemplos no convertibles: ") + castImpact.examples.joined(separator: " · ")).font(.caption).textSelection(.enabled)
              }
            }
            if let castIssue { Text(D(castIssue)).font(.caption).foregroundStyle(.red) }
          }
          if action == "derive" {
            Picker(L("Aritmética"), selection: $arithmetic) {
              ForEach(Arithmetic.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            TextField(L("Constante numérica (punto decimal)"), text: $value)
          }
          if action == "sort" {
            Text(L("Orden ascendente, ausentes al final.")).foregroundStyle(.secondary)
          }
          if action == "select" {
            ColumnChecklist(columns: dataset.columns, selected: $selectedColumns)
          }
          if action == "aggregate" {
            Picker(L("Agrupar por"), selection: $group) {
              ForEach(dataset.columns) { Text($0.name).tag($0.name) }
            }
            Picker(L("Agregación"), selection: $aggregate) {
              ForEach(Aggregate.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
          }
        }.formStyle(.grouped)
        Button(L("Crear versión"), action: apply).buttonStyle(.borderedProminent).tint(.primary)
          .disabled(action == "cast" && (castChecking || castImpact == nil))
        }
        if purpose != .transform {
        Divider()
        Text(L("Calidad de datos")).font(.title2.weight(.semibold))
        Text(
          L("Nulos, valores no finitos y candidatos IQR se revisan en todas las columnas pertinentes. Define claves para duplicados o un rango adicional.")
        ).foregroundStyle(.secondary)
        DisclosureGroup(L("Claves de duplicados")) {
          ColumnChecklist(columns: dataset.columns, selected: $duplicateKeys).padding(.top, 8)
        }
        Toggle(L("Comprobar rango de la columna seleccionada"), isOn: $rangeEnabled)
        if rangeEnabled {
          HStack {
            Text(column)
            TextField(L("Mínimo"), text: $lower)
            TextField(L("Máximo"), text: $upper)
          }.textFieldStyle(.roundedBorder)
        }
        Button(L("Revisar calidad")) {
          acceptDraft()
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
                Text(D(finding.rule.label)).font(.headline)
                Text(
                  L("\(finding.affectedRows) filas candidatas · una detección no confirma un error")
                ).foregroundStyle(.secondary).font(.caption)
              }
              Spacer()
              Button(L("Ver evidencia")) { workspace.showEvidence(finding) }.disabled(
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
      draftRevision = workspace.inspectorRevision
      draftBaseline = currentDraft
      if let draftKey, case .preparation(let draft) = workspace.inspectorDrafts[draftKey] { restoreDraft(draft) }
    }
    .onChange(of: currentDraft) { cacheDraft() }
    .onDisappear { cacheDraft() }
    .task(id: castKey) {
      castImpact = nil; castIssue = nil; castChecking = false
      guard castKey.active, !castKey.column.isEmpty else { return }
      let key = castKey; castChecking = true
      defer { if !Task.isCancelled { castChecking = false } }
      do {
        let impact = try await workspace.engine.castImpact(datasetID: key.datasetID, column: key.column, type: key.type)
        try Task.checkCancellation(); castImpact = impact
      } catch is CancellationError {} catch { castIssue = error.localizedDescription }
    }
    .alert(L("La conversión crea valores ausentes"), isPresented: $confirmCast) {
      Button(L("Conservar entrada"), role: .cancel) {}
      Button(L("Crear versión (nuevos NULL: \(castImpact?.newNulls ?? 0))"), role: .destructive) { apply(confirmed: true) }
    } message: {
      Text(L("\(castImpact?.newNulls ?? 0) valores de «\(column)» no se pueden convertir a \(physicalType.rawValue). Se guardará una versión nueva; la entrada permanecerá intacta."))
    }
  }
  private var currentDraft: PreparationDraft {
    var draft = PreparationDraft()
    draft.column = column
    draft.action = action
    draft.comparison = comparison
    draft.value = value
    draft.newName = newName
    draft.physicalType = physicalType
    draft.arithmetic = arithmetic
    draft.aggregate = aggregate
    draft.group = group
    draft.selectedColumns = selectedColumns
    draft.duplicateKeys = duplicateKeys
    draft.lower = lower
    draft.upper = upper
    draft.rangeEnabled = rangeEnabled
    return draft
  }
  private func restoreDraft(_ draft: PreparationDraft) {
    column = draft.column
    action = draft.action
    comparison = draft.comparison
    value = draft.value
    newName = draft.newName
    physicalType = draft.physicalType
    arithmetic = draft.arithmetic
    aggregate = draft.aggregate
    group = draft.group
    selectedColumns = draft.selectedColumns
    duplicateKeys = draft.duplicateKeys
    lower = draft.lower
    upper = draft.upper
    rangeEnabled = draft.rangeEnabled
  }
  private func cacheDraft() {
    guard let draftBaseline, draftRevision == workspace.inspectorRevision else { return }
    workspace.recordDraft(currentDraft == draftBaseline ? nil : .preparation(currentDraft), for: draftKey)
  }
  private func acceptDraft() {
    draftBaseline = currentDraft; workspace.recordDraft(nil, for: draftKey)
  }
  private func apply() { apply(confirmed: false) }
  private func apply(confirmed: Bool) {
    let operation: Transformation
    switch action {
    case "select":
      operation = .select(
        columns: dataset.columns.map(\.name).filter { selectedColumns.contains($0) })
    case "rename": operation = .rename(column: column, name: newName)
    case "cast":
      guard let castImpact, castImpact.approval.datasetID == dataset.id,
        castImpact.approval.column == column, castImpact.approval.type == physicalType else { return }
      if castImpact.newNulls > 0 && !confirmed { confirmCast = true; return }
      operation = .cast(column: column, type: physicalType)
    case "derive":
      guard let number = Double(value), number.isFinite else {
        workspace.error = L("La constante debe ser numérica (usa punto decimal).")
        return
      }
      operation = .derive(column: column, operation: arithmetic, value: number, name: newName)
    case "sort": operation = .sort(column: column, ascending: true)
    case "aggregate": operation = .aggregate(group: group, column: column, function: aggregate)
    default: operation = .filter(column: column, comparison: comparison, value: value)
    }
    acceptDraft()
    let approval = action == "cast" ? castImpact?.approval : nil
    if let onApply { onApply(operation, approval) } else { workspace.transform(operation, castApproval: approval) }
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
private struct CastPreviewKey: Hashable {
  let datasetID: UUID; let column: String; let type: PhysicalType; let active: Bool
}
