import SwiftUI
import VapulaCore

struct MissingValuesView: View {
  let workspace: Workspace
  let dataset: DatasetVersion
  var draftKey: InspectorDraftKey? = nil
  @State private var draftRevision = -1
  @State private var draftBaseline: MissingDraft?
  let initial: Transformation?
  let apply: (Transformation) -> Void
  @State private var selected = Set<String>()
  @State private var method = "mean"
  @State private var constant = ""
  @State private var blanks = true
  @State private var nonfinite = true
  @State private var impact: MissingImpact?
  @State private var checking = false
  @State private var issue: String?
  private var numericOnly: Bool { !selected.isEmpty && dataset.columns.filter { selected.contains($0.name) }.allSatisfy(\.isNumeric) }
  private var key: MissingPreviewKey { MissingPreviewKey(dataset: dataset.id, columns: selected.sorted(), blanks: blanks, nonfinite: nonfinite) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 19) {
        Text(L("Qué valores tratar")).font(.headline)
        Text(L("NULL siempre se considera ausente. Decide si también incluir textos vacíos y números no finitos.")).font(.caption).foregroundStyle(.secondary)
        Toggle(L("Incluir texto vacío o con espacios"), isOn: $blanks)
        Toggle(L("Incluir NaN e infinitos"), isOn: $nonfinite)
        Divider()
        HStack {
          Text(L("Columnas")).font(.headline)
          Spacer()
          Menu {
            Button(L("Todas")) { selected = Set(dataset.columns.map(\.name)) }
            Button(L("Solo numéricas")) { selected = Set(dataset.columns.filter(\.isNumeric).map(\.name)) }
            Button(L("Ninguna")) { selected = [] }
          } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
        }
        ScrollView {
          VStack(alignment: .leading, spacing: 9) {
            ForEach(dataset.columns) { column in
              Toggle(isOn: Binding(get: { selected.contains(column.name) }, set: { if $0 { selected.insert(column.name) } else { selected.remove(column.name) } })) {
                HStack {
                  Text(column.name).lineLimit(1)
                  Spacer()
                  if let count = impact?.counts[column.name] { Text(L("\(count)")).monospacedDigit().foregroundStyle(.secondary) }
                }
              }.toggleStyle(.checkbox)
            }
          }.padding(.trailing, 4)
        }.frame(maxHeight: 150)
        Divider()
        Text(L("Cómo resolverlos")).font(.headline)
        Picker(L("Acción"), selection: $method) {
          Text(L("Media")).tag("mean").disabled(!numericOnly)
          Text(L("Mediana")).tag("median").disabled(!numericOnly)
          Text(L("Moda")).tag("mode")
          Text(L("Valor indicado")).tag("constant")
          Text(L("Retirar filas afectadas")).tag("dropRows")
          Text(L("Retirar columnas afectadas")).tag("dropColumns")
        }.labelsHidden()
        if method == "constant" {
          TextField(L("Valor de reemplazo"), text: $constant).textFieldStyle(.roundedBorder)
          Text(L("Se comprueba el tipo de cada columna. Los valores incompatibles se rechazan.")).font(.caption).foregroundStyle(.secondary)
        }
        if method == "mean" || method == "median" {
          Text(L("Media y mediana usan los valores observados de cada columna; la salida numérica pasa a DOUBLE. La imputación puede reducir la dispersión y cambiar asociaciones.")).font(.caption).foregroundStyle(.secondary)
        }
        if method == "mode" {
          Text(L("Se usa el valor observado más frecuente. En empates se elige el menor según el orden del tipo de datos.")).font(.caption).foregroundStyle(.secondary)
        }
        if let impact {
          VStack(alignment: .leading, spacing: 7) {
            Text(L("Impacto antes de aplicar")).font(.headline)
            Text(L("\(impact.affectedCells) celdas · \(impact.affectedRows) de \(impact.totalRows) filas")).monospacedDigit()
            Text(L("Se creará una versión nueva. La versión de entrada se conserva.")).font(.caption).foregroundStyle(.secondary)
          }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        if checking { HStack { ProgressView().controlSize(.small); Text(L("Contando valores…")).font(.caption) } }
        if let issue { Text(D(issue)).font(.caption).foregroundStyle(.secondary) }
        Button(L("Aplicar y crear versión")) {
          let action: MissingAction
          switch method {
          case "median": action = .median; case "mode": action = .mode
          case "constant": action = .constant(constant); case "dropRows": action = .dropRows
          case "dropColumns": action = .dropColumns; default: action = .mean
          }
          acceptDraft()
          apply(.missing(columns: selected.sorted(), action: action, policy: MissingPolicy(blankText: blanks, nonFiniteNumbers: nonfinite)))
        }.buttonStyle(.borderedProminent).disabled(checking || impact == nil || impact?.affectedCells == 0 || selected.isEmpty || (method == "constant" && constant.isEmpty) || (["mean", "median"].contains(method) && !numericOnly))
      }.font(.system(size: 12)).padding(16)
    }
    .disabled(workspace.busy)
    .onAppear {
      if case .missing(let columns, let action, let policy) = initial {
        selected = Set(columns); blanks = policy.blankText; nonfinite = policy.nonFiniteNumbers
        switch action {
        case .mean: method = "mean"; case .median: method = "median"; case .mode: method = "mode"
        case .dropRows: method = "dropRows"; case .dropColumns: method = "dropColumns"
        case .constant(let value): method = "constant"; constant = value
        }
      } else {
        let first = dataset.columns.first { $0.isNumeric && $0.name.lowercased() != "id" } ?? dataset.columns.first
        selected = Set(first.map { [$0.name] } ?? []); method = first?.isNumeric == true ? "mean" : "mode"
      }
      draftRevision = workspace.inspectorRevision
      draftBaseline = currentDraft
      if let draftKey, case .missing(let draft) = workspace.inspectorDrafts[draftKey] { restoreDraft(draft) }
    }
    .onChange(of: currentDraft) { cacheDraft() }
    .onDisappear { cacheDraft() }
    .onChange(of: numericOnly) { if !numericOnly && ["mean", "median"].contains(method) { method = "mode" } }
    .task(id: key) {
      impact = nil; issue = nil; checking = false
      guard !key.columns.isEmpty else { return }
      checking = true
      defer { if !Task.isCancelled { checking = false } }
      do {
        let value = try await workspace.engine.missingImpact(datasetID: key.dataset, columns: key.columns, policy: MissingPolicy(blankText: key.blanks, nonFiniteNumbers: key.nonfinite))
        try Task.checkCancellation(); impact = value
      } catch is CancellationError {} catch { issue = error.localizedDescription }
    }
  }
  private var currentDraft: MissingDraft {
    var draft = MissingDraft()
    draft.selected = selected
    draft.method = method
    draft.constant = constant
    draft.blanks = blanks
    draft.nonfinite = nonfinite
    return draft
  }
  private func restoreDraft(_ draft: MissingDraft) {
    selected = draft.selected
    method = draft.method
    constant = draft.constant
    blanks = draft.blanks
    nonfinite = draft.nonfinite
  }
  private func cacheDraft() {
    guard let draftBaseline, draftRevision == workspace.inspectorRevision else { return }
    workspace.recordDraft(currentDraft == draftBaseline ? nil : .missing(currentDraft), for: draftKey)
  }
  private func acceptDraft() {
    draftBaseline = currentDraft; workspace.recordDraft(nil, for: draftKey)
  }
}
private struct MissingPreviewKey: Hashable {
  let dataset: UUID; let columns: [String]; let blanks: Bool; let nonfinite: Bool
}
