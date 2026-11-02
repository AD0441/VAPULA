import SwiftUI
import VapulaCore

struct StatisticsView: View {
  let workspace: Workspace
  let dataset: DatasetVersion
  var draftKey: InspectorDraftKey? = nil
  @State private var draftRevision = -1
  @State private var draftBaseline: StatisticsDraft?
  var initial: AnalysisSpecification? = nil
  var onCalculate: ((AnalysisSpecification) -> Void)? = nil
  var compact = false
  @State private var method = AnalysisMethod.descriptive
  @State private var x = ""
  @State private var y = ""
  @State private var group = ""
  @State private var groupA = ""
  @State private var groupB = ""
  @State private var groupLevels: [String] = []
  @State private var groupError: String?
  @State private var referenceMean = "0"
  @State private var alpha = 0.05
  private var numeric: [ColumnDefinition] { dataset.columns.filter(\.isNumeric) }
  private var candidates: [ColumnDefinition] { method == .chiSquare ? dataset.columns : numeric }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        if !compact { Text("Laboratorio estadístico").font(.title2.weight(.semibold)) }
        Text(
          "Elige una pregunta, revisa sus requisitos y conserva el resultado con su versión de datos."
        ).foregroundStyle(.secondary)
        Form {
          Picker("Prueba", selection: $method) {
            Section("Describir") {
              Text(AnalysisMethod.descriptive.title).tag(AnalysisMethod.descriptive)
            }
            Section("Comparar medias") {
              ForEach([AnalysisMethod.oneSampleT, .pairedT, .welch, .anova], id: \.self) {
                Text($0.title).tag($0)
              }
            }
            Section("Asociación y distribución") {
              ForEach([AnalysisMethod.pearson, .spearman, .mannWhitney, .chiSquare], id: \.self) {
                Text($0.title).tag($0)
              }
            }
            Section("Modelar") {
              Text(AnalysisMethod.regression.title).tag(AnalysisMethod.regression)
            }
          }
          Picker(method == .chiSquare ? "Variable categórica X" : "Variable X", selection: $x) {
            ForEach(candidates) { Text($0.name).tag($0.name) }
          }
          if method.needsPair {
            Picker(method == .chiSquare ? "Variable categórica Y" : "Variable Y", selection: $y) {
              ForEach(candidates) { Text($0.name).tag($0.name) }
            }
          }
          if method == .oneSampleT {
            TextField("Media de referencia μ0 (punto decimal)", text: $referenceMean)
          }
          if method.needsGrouping {
            Picker("Variable de grupo", selection: $group) {
              ForEach(dataset.columns) { Text($0.name).tag($0.name) }
            }
            if method.needsTwoGroups {
              if groupLevels.isEmpty {
                Text("Elige una columna de grupo con al menos dos categorías.").foregroundStyle(
                  .secondary)
              } else {
                Picker("Grupo A", selection: $groupA) {
                  ForEach(groupLevels, id: \.self) { Text($0).tag($0) }
                }
                Picker("Grupo B", selection: $groupB) {
                  ForEach(groupLevels, id: \.self) { Text($0).tag($0) }
                }
              }
            }
            if let groupError { Text(groupError).foregroundStyle(.secondary) }
          }
          if method.supportsAlpha {
            Picker("Nivel de significación α", selection: $alpha) {
              Text("0.01").tag(0.01)
              Text("0.05").tag(0.05)
              Text("0.10").tag(0.10)
            }
          }
        }.formStyle(.grouped)
        VStack(alignment: .leading, spacing: 10) {
          Text(method.title).font(.headline)
          Text(method.explanation).fixedSize(horizontal: false, vertical: true)
          Label(
            "La escala de medición debe revisarse. Nulos y valores no finitos se excluyen de forma explícita; una asociación no implica causalidad.",
            systemImage: "info.circle"
          ).font(.callout).foregroundStyle(.secondary)
          Text(
            "Los análisis que materializan observaciones aceptan hasta 200.000 filas. Descriptivos, frecuencias y contingencias se consultan sobre todos los registros."
          ).font(.caption).foregroundStyle(.secondary)
        }
        ViewThatFits(in: .horizontal) {
          HStack { calculationButtons }
          VStack(alignment: .leading, spacing: 10) { calculationButtons }
        }
        if let p = workspace.profiles.first(where: { $0.column.name == x }) {
          Text("\(x): \(p.valid) válidos · \(p.missing) ausentes/no finitos").font(.callout)
            .foregroundStyle(.secondary)
        }
      }.padding(compact ? 16 : 30).frame(maxWidth: compact ? .infinity : 1000, alignment: .leading)
    }.disabled(workspace.busy)
      .task {
        if let initial {
          method = initial.method; x = initial.x; y = initial.y
          group = initial.group; groupA = initial.groupA; groupB = initial.groupB
          alpha = initial.alpha; referenceMean = String(initial.hypothesizedMean ?? 0)
        }
        seedVariables()
        draftRevision = workspace.inspectorRevision
        draftBaseline = currentDraft
        if let draftKey, case .statistics(let draft) = workspace.inspectorDrafts[draftKey] { restoreDraft(draft) }
      }
      .onChange(of: currentDraft) { cacheDraft() }
      .onDisappear { cacheDraft() }
      .onChange(of: method) { seedVariables() }
      .task(id: "\(method.rawValue):\(group)") {
        guard method.needsGrouping, group.isEmpty == false else { return }
        do {
          let levels = try await workspace.engine.groupLabels(datasetID: dataset.id, column: group)
          guard Task.isCancelled == false else { return }
          groupLevels = levels
          groupError = nil
          if levels.contains(groupA) == false { groupA = levels.first ?? "" }
          if levels.contains(groupB) == false || groupB == groupA {
            groupB = levels.first { $0 != groupA } ?? ""
          }
        } catch is CancellationError {} catch { groupError = error.localizedDescription }
      }
  }
  @ViewBuilder private var calculationButtons: some View {
    Button(compact ? "Ejecutar paso" : "Calcular y guardar resultado", action: calculate)
      .buttonStyle(.borderedProminent).tint(.primary).disabled(cannotCalculate).fixedSize()
    Button("Consultar válidos y ausentes", action: workspace.profile).fixedSize()
  }
  private var cannotCalculate: Bool {
    x.isEmpty || (method.needsPair && y.isEmpty)
      || (method.needsTwoGroups && (groupA.isEmpty || groupA == groupB))
      || (method == .oneSampleT && Double(referenceMean) == nil)
  }
  private func seedVariables() {
    if candidates.contains(where: { $0.name == x }) == false { x = candidates.first?.name ?? "" }
    if candidates.contains(where: { $0.name == y }) == false {
      y = candidates.first { $0.name != x }?.name ?? x
    }
    if group.isEmpty {
      group =
        dataset.columns.first(where: { $0.isNumeric == false })?.name ?? dataset.columns.first?.name
        ?? ""
    }
  }
  private var currentDraft: StatisticsDraft {
    var draft = StatisticsDraft()
    draft.method = method
    draft.x = x
    draft.y = y
    draft.group = group
    draft.groupA = groupA
    draft.groupB = groupB
    draft.referenceMean = referenceMean
    draft.alpha = alpha
    return draft
  }
  private func restoreDraft(_ draft: StatisticsDraft) {
    method = draft.method
    x = draft.x
    y = draft.y
    group = draft.group
    groupA = draft.groupA
    groupB = draft.groupB
    referenceMean = draft.referenceMean
    alpha = draft.alpha
  }
  private func cacheDraft() {
    guard let draftBaseline, draftRevision == workspace.inspectorRevision else { return }
    workspace.recordDraft(currentDraft == draftBaseline ? nil : .statistics(currentDraft), for: draftKey)
  }
  private func acceptDraft() {
    draftBaseline = currentDraft; workspace.recordDraft(nil, for: draftKey)
  }
  private func calculate() {
    let mean: Double
    if method == .oneSampleT {
      guard let value = Double(referenceMean), value.isFinite else {
        workspace.error = "La media de referencia debe ser un número finito. Revisa el valor antes de calcular."
        return
      }
      mean = value
    } else { mean = 0 }
    let specification = AnalysisSpecification(
        method: method, x: x, y: method.needsPair ? y : "",
        group: method.needsGrouping ? group : "", groupA: method.needsTwoGroups ? groupA : "",
        groupB: method.needsTwoGroups ? groupB : "", alpha: alpha,
        hypothesizedMean: mean)
    acceptDraft()
    if let onCalculate { onCalculate(specification) } else { workspace.analyze(specification) }
  }
}
