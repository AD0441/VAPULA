import Charts
import SwiftUI
import VapulaCore
import VapulaData

struct StatisticalChartView: View {
  let configuration: ChartConfiguration
  let histogram: [ChartPoint]
  let scatter: [ChartPoint]
  let frequencies: [Frequency]
  let box: BoxSummary?
  let xName: String
  let yName: String
  let histogramWidth: Double?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if hasData {
        if configuration.kind == .boxplot, let box {
          BoxplotChart(
            summary: box, color: accent, lineWidth: configuration.lineWidth,
            showGrid: configuration.showGrid
          )
          .chartYAxisLabel(yAxisTitle)
        } else {
          Chart { marks }
            .chartXAxis {
              AxisMarks { _ in
                if configuration.showGrid { AxisGridLine() }
                AxisTick()
                AxisValueLabel()
              }
            }
            .chartYAxis {
              AxisMarks { _ in
                if configuration.showGrid { AxisGridLine() }
                AxisTick()
                AxisValueLabel()
              }
            }
            .chartXAxisLabel(xAxisTitle)
            .chartYAxisLabel(yAxisTitle)
            .chartLegend(.hidden)
        }
      } else {
        ContentUnavailableView(
          emptyTitle, systemImage: "chart.xyaxis.line",
          description: Text("Elige las variables apropiadas y pulsa Actualizar datos."))
      }
    }
    .padding(.vertical, 14)
  }

  @ChartContentBuilder
  private var marks: some ChartContent {
    switch configuration.kind {
    case .histogram:
      ForEach(finiteHistogram) { point in
        if let width = histogramWidth {
          RectangleMark(
            xStart: .value("Inicio de intervalo", point.x - width / 2),
            xEnd: .value("Fin de intervalo", point.x + width / 2),
            yStart: .value("Base", 0),
            yEnd: .value("Frecuencia", point.y)
          )
          .foregroundStyle(accent)
        } else {
          BarMark(x: .value("Valor", point.x), y: .value("Frecuencia", point.y))
            .foregroundStyle(accent)
        }
      }
    case .verticalBar:
      ForEach(frequencies) { point in
        BarMark(x: .value("Categoría", point.label), y: .value("Frecuencia", point.count))
          .foregroundStyle(categoryColor(point.label))
          .accessibilityLabel(point.label).accessibilityValue("\(point.count)")
      }
    case .horizontalBar:
      ForEach(frequencies) { point in
        BarMark(x: .value("Frecuencia", point.count), y: .value("Categoría", point.label))
          .foregroundStyle(categoryColor(point.label))
          .accessibilityLabel(point.label).accessibilityValue("\(point.count)")
      }
    case .lollipop:
      ForEach(frequencies) { point in
        RuleMark(
          xStart: .value("Origen", 0), xEnd: .value("Frecuencia", point.count),
          y: .value("Categoría", point.label)
        )
        .lineStyle(StrokeStyle(lineWidth: CGFloat(configuration.lineWidth)))
        .foregroundStyle(categoryColor(point.label))
        PointMark(x: .value("Frecuencia", point.count), y: .value("Categoría", point.label))
          .symbol(symbol).symbolSize(CGFloat(configuration.pointSize))
          .foregroundStyle(categoryColor(point.label))
          .accessibilityLabel(point.label).accessibilityValue("\(point.count)")
      }
    case .scatter:
      ForEach(finiteScatter) { point in
        PointMark(x: .value("X", point.x), y: .value("Y", point.y))
          .symbol(symbol).symbolSize(CGFloat(configuration.pointSize))
          .foregroundStyle(accent.opacity(0.82))
      }
    case .line:
      ForEach(orderedPoints) { point in
        LineMark(x: .value("X", point.x), y: .value("Y", point.y))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: CGFloat(configuration.lineWidth)))
          .foregroundStyle(accent)
        if configuration.showPoints {
          PointMark(x: .value("X", point.x), y: .value("Y", point.y))
            .symbol(symbol).symbolSize(CGFloat(configuration.pointSize)).foregroundStyle(accent)
        }
      }
    case .area:
      ForEach(orderedPoints) { point in
        AreaMark(x: .value("X", point.x), y: .value("Y", point.y))
          .interpolationMethod(.linear).foregroundStyle(accent.opacity(0.22))
        LineMark(x: .value("X", point.x), y: .value("Y", point.y))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: CGFloat(configuration.lineWidth))).foregroundStyle(
            accent)
        if configuration.showPoints {
          PointMark(x: .value("X", point.x), y: .value("Y", point.y))
            .symbol(symbol).symbolSize(CGFloat(configuration.pointSize)).foregroundStyle(accent)
        }
      }
    case .boxplot:
      // The dedicated boxplot view supplies its numeric x domain and hidden x axis.
      RuleMark(y: .value("Sin datos", 0)).foregroundStyle(.clear)
    }
  }

  private var finiteHistogram: [ChartPoint] { histogram.filter { $0.x.isFinite && $0.y.isFinite } }
  private var finiteScatter: [ChartPoint] { scatter.filter { $0.x.isFinite && $0.y.isFinite } }
  private var orderedPoints: [ChartPoint] {
    finiteScatter.sorted { $0.x == $1.x ? $0.id < $1.id : $0.x < $1.x }
  }
  private var hasData: Bool {
    switch configuration.kind {
    case .histogram: finiteHistogram.isEmpty == false
    case .verticalBar, .horizontalBar, .lollipop: frequencies.isEmpty == false
    case .scatter, .line, .area: finiteScatter.isEmpty == false
    case .boxplot: box != nil
    }
  }
  private var emptyTitle: String {
    switch configuration.kind {
    case .scatter, .line, .area: "No hay pares numéricos finitos"
    case .histogram, .boxplot: "Selecciona una variable numérica"
    default: "No hay frecuencias disponibles"
    }
  }
  private var accent: Color {
    if configuration.palette == .graphite { return .primary }
    if configuration.palette == .custom { return Color(chartHex: configuration.customColorHex) }
    return Color(chartHex: configuration.palette.hexColors.first ?? "#256A8A")
  }
  private func categoryColor(_ label: String) -> Color {
    if configuration.palette == .graphite {
      return .primary.opacity(colorScheme == .dark ? 0.85 : 0.8)
    }
    if configuration.palette == .custom { return accent }
    let colors = configuration.palette.hexColors
    let index = frequencies.firstIndex(where: { $0.label == label }) ?? 0
    return Color(chartHex: colors[index % colors.count])
  }
  private var symbol: BasicChartSymbolShape {
    switch configuration.pointShape {
    case .circle: .circle
    case .square: .square
    case .diamond: .diamond
    case .triangle: .triangle
    }
  }
  private var xAxisTitle: String {
    if configuration.xLabel.isEmpty == false { return configuration.xLabel }
    switch configuration.kind {
    case .horizontalBar, .lollipop: return "Frecuencia"
    case .boxplot: return ""
    default: return xName
    }
  }
  private var yAxisTitle: String {
    if configuration.yLabel.isEmpty == false { return configuration.yLabel }
    switch configuration.kind {
    case .histogram, .verticalBar: return "Frecuencia"
    case .horizontalBar, .lollipop, .boxplot: return xName
    case .scatter, .line, .area: return yName
    }
  }
}

struct BoxplotChart: View {
  let summary: BoxSummary
  let color: Color
  let lineWidth: Double
  let showGrid: Bool

  var body: some View {
    Chart {
      RuleMark(
        x: .value("Variable", 1), yStart: .value("Bigote inferior", summary.lower),
        yEnd: .value("Bigote superior", summary.upper)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(lineWidth))).foregroundStyle(color)
      RectangleMark(
        xStart: .value("Inicio", 0.8), xEnd: .value("Fin", 1.2),
        yStart: .value("Q1", summary.q1), yEnd: .value("Q3", summary.q3)
      )
      .foregroundStyle(color.opacity(0.24))
      RuleMark(
        xStart: .value("Inicio", 0.8), xEnd: .value("Fin", 1.2),
        y: .value("Mediana", summary.median)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(max(2, lineWidth)))).foregroundStyle(color)
      RuleMark(
        xStart: .value("Inicio", 0.9), xEnd: .value("Fin", 1.1),
        y: .value("Bigote inferior", summary.lower)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(lineWidth))).foregroundStyle(color)
      RuleMark(
        xStart: .value("Inicio", 0.9), xEnd: .value("Fin", 1.1),
        y: .value("Bigote superior", summary.upper)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(lineWidth))).foregroundStyle(color)
    }
    .chartXScale(domain: 0.4...1.6)
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks { _ in
        if showGrid { AxisGridLine() }
        AxisTick()
        AxisValueLabel()
      }
    }
    .accessibilityLabel(
      "Boxplot: Q1 \(summary.q1), mediana \(summary.median), Q3 \(summary.q3), bigotes \(summary.lower) y \(summary.upper), \(summary.outliers) candidatos fuera de los bigotes"
    )
  }
}
