import Charts
import SwiftUI
import VapulaCore
import VapulaData

struct VisualizationView: View {
  @Bindable var workspace: Workspace
  let dataset: DatasetVersion
  @State private var x = ""
  @State private var y = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .firstTextBaseline) {
        Text("Estudio de gráficos").font(.title2.weight(.semibold))
        Spacer()
        Picker("Tipo", selection: $workspace.chartConfiguration.kind) {
          ForEach(ChartKind.allCases) { kind in Text(LocalizedStringKey(kind.title)).tag(kind) }
        }.frame(width: 260)
      }
      HStack(spacing: 14) {
        Picker("X", selection: $x) {
          ForEach(dataset.columns) { Text($0.name).tag($0.name) }
        }
        Picker("Y", selection: $y) {
          Text("Sin variable Y").tag("")
          ForEach(dataset.columns.filter(\.isNumeric)) { Text($0.name).tag($0.name) }
        }
        Button("Actualizar datos") { workspace.charts(x: x, y: y) }.fixedSize()
      }.disabled(workspace.busy)
      if hasPendingDataChoices {
        Label(
          "Las variables o los intervalos cambiaron. Pulsa Actualizar datos para aplicarlos.",
          systemImage: "arrow.clockwise"
        )
        .font(.callout).foregroundStyle(.secondary)
      }
      Divider()
      HSplitView {
        VStack(alignment: .leading, spacing: 12) {
          if workspace.chartDescription.isEmpty {
            ContentUnavailableView(
              "Elige variables y pulsa Actualizar datos", systemImage: "chart.bar"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            if workspace.chartConfiguration.title.isEmpty == false {
              Text(workspace.chartConfiguration.title).font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(workspace.chartDescription).font(.caption).foregroundStyle(.secondary)
              .textSelection(.enabled)
            StatisticalChartView(
              configuration: workspace.chartConfiguration.normalized(),
              histogram: workspace.histogram,
              scatter: workspace.scatter,
              frequencies: workspace.frequencies,
              box: workspace.boxSummary,
              xName: workspace.chartX,
              yName: workspace.chartY,
              histogramWidth: histogramWidth
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(caption).font(.caption).foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }.padding(.trailing, 20).frame(minWidth: 340)
        ChartStylePanel(configuration: $workspace.chartConfiguration, isBusy: workspace.busy) {
          workspace.persistChartConfiguration()
        }.frame(minWidth: 230, idealWidth: 260, maxWidth: 310)
      }
    }
    .padding(24)
    .task {
      x =
        dataset.columns.contains(where: { $0.name == workspace.chartX })
        ? workspace.chartX
        : dataset.columns.first(where: \.isNumeric)?.name ?? dataset.columns.first?.name ?? ""
      y =
        dataset.columns.contains(where: { $0.name == workspace.chartY && $0.isNumeric })
        ? workspace.chartY
        : dataset.columns.filter(\.isNumeric).dropFirst().first?.name ?? ""
    }
  }

  private var hasPendingDataChoices: Bool {
    workspace.chartDescription.isEmpty == false
      && (x != workspace.chartX || y != workspace.chartY
        || (workspace.chartConfiguration.kind == .histogram
          && workspace.chartConfiguration.binCount != workspace.chartBinCount))
  }
  private var histogramWidth: Double? {
    guard let profile = workspace.chartProfile,
      let low = profile.minimum.flatMap(Double.init),
      let high = profile.maximum.flatMap(Double.init), high > low,
      workspace.chartBinCount > 0
    else { return nil }
    let width = (high - low) / Double(workspace.chartBinCount)
    return width.isFinite && width > 0 ? width : nil
  }
  private var caption: String {
    switch workspace.chartConfiguration.kind {
    case .verticalBar, .horizontalBar, .lollipop:
      "Hasta 30 categorías más frecuentes; recuentos exactos del conjunto completo. NULL se indica explícitamente."
    case .scatter:
      "Primeros 2.000 pares finitos, sin inferir representatividad. Esta vista no modifica los análisis ni sus tamaños muestrales."
    case .line, .area:
      "Primeros 2.000 pares finitos, ordenados por X para dibujar. La línea no implica una secuencia temporal, causalidad ni representatividad de la muestra."
    case .boxplot:
      "Cuartiles tipo 7. Bigotes: observaciones extremas dentro de 1,5 IQR. Los puntos fuera de los bigotes se omiten en el dibujo; candidatos: \(workspace.boxSummary?.outliers ?? 0)."
    case .histogram:
      "\(workspace.chartBinCount) intervalos de igual amplitud (uno si la variable es constante). Recuentos del conjunto completo; se omiten intervalos vacíos. Nulos y valores no finitos excluidos."
    }
  }
}

extension ChartKind {
  var title: String {
    switch self {
    case .histogram: "Histograma"
    case .verticalBar: "Barras verticales"
    case .horizontalBar: "Barras horizontales"
    case .scatter: "Dispersión"
    case .line: "Línea"
    case .area: "Área"
    case .boxplot: "Boxplot"
    case .lollipop: "Puntos y tallos"
    }
  }
}
