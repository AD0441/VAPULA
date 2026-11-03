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
          T(emptyTitle), systemImage: "chart.xyaxis.line",
          description: Text(L("Elige las variables apropiadas y pulsa Actualizar datos.")))
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
            xStart: .value(L("Inicio de intervalo"), point.x - width / 2),
            xEnd: .value(L("Fin de intervalo"), point.x + width / 2),
            yStart: .value(L("Base"), 0),
            yEnd: .value(L("Frecuencia"), point.y)
          )
          .foregroundStyle(accent)
        } else {
          BarMark(x: .value(L("Valor"), point.x), y: .value(L("Frecuencia"), point.y))
            .foregroundStyle(accent)
        }
      }
    case .verticalBar:
      ForEach(frequencies) { point in
        BarMark(x: .value(L("Categoría"), point.label), y: .value(L("Frecuencia"), point.count))
          .foregroundStyle(categoryColor(point.label))
          .accessibilityLabel(point.label).accessibilityValue(L("\(point.count)"))
      }
    case .horizontalBar:
      ForEach(frequencies) { point in
        BarMark(x: .value(L("Frecuencia"), point.count), y: .value(L("Categoría"), point.label))
          .foregroundStyle(categoryColor(point.label))
          .accessibilityLabel(point.label).accessibilityValue(L("\(point.count)"))
      }
    case .lollipop:
      ForEach(frequencies) { point in
        RuleMark(
          xStart: .value(L("Origen"), 0), xEnd: .value(L("Frecuencia"), point.count),
          y: .value(L("Categoría"), point.label)
        )
        .lineStyle(StrokeStyle(lineWidth: CGFloat(configuration.lineWidth)))
        .foregroundStyle(categoryColor(point.label))
        PointMark(x: .value(L("Frecuencia"), point.count), y: .value(L("Categoría"), point.label))
          .symbol(symbol).symbolSize(CGFloat(configuration.pointSize))
          .foregroundStyle(categoryColor(point.label))
          .accessibilityLabel(point.label).accessibilityValue(L("\(point.count)"))
      }
    case .scatter:
      ForEach(finiteScatter) { point in
        PointMark(x: .value(L("X"), point.x), y: .value(L("Y"), point.y))
          .symbol(symbol).symbolSize(CGFloat(configuration.pointSize))
          .foregroundStyle(accent.opacity(0.82))
      }
    case .line:
      ForEach(orderedPoints) { point in
        LineMark(x: .value(L("X"), point.x), y: .value(L("Y"), point.y))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: CGFloat(configuration.lineWidth)))
          .foregroundStyle(accent)
        if configuration.showPoints {
          PointMark(x: .value(L("X"), point.x), y: .value(L("Y"), point.y))
            .symbol(symbol).symbolSize(CGFloat(configuration.pointSize)).foregroundStyle(accent)
        }
      }
    case .area:
      ForEach(orderedPoints) { point in
        AreaMark(x: .value(L("X"), point.x), y: .value(L("Y"), point.y))
          .interpolationMethod(.linear).foregroundStyle(accent.opacity(0.22))
        LineMark(x: .value(L("X"), point.x), y: .value(L("Y"), point.y))
          .interpolationMethod(.linear)
          .lineStyle(StrokeStyle(lineWidth: CGFloat(configuration.lineWidth))).foregroundStyle(
            accent)
        if configuration.showPoints {
          PointMark(x: .value(L("X"), point.x), y: .value(L("Y"), point.y))
            .symbol(symbol).symbolSize(CGFloat(configuration.pointSize)).foregroundStyle(accent)
        }
      }
    case .boxplot:
      // The dedicated boxplot view supplies its numeric x domain and hidden x axis.
      RuleMark(y: .value(L("Sin datos"), 0)).foregroundStyle(.clear)
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
    return adaptiveColor(configuration.palette.hexColors.first ?? "#256A8A")
  }
  private func categoryColor(_ label: String) -> Color {
    if configuration.palette == .graphite {
      return .primary.opacity(colorScheme == .dark ? 0.85 : 0.8)
    }
    if configuration.palette == .custom { return accent }
    let colors = configuration.palette.hexColors
    let index = frequencies.firstIndex(where: { $0.label == label }) ?? 0
    return adaptiveColor(colors[index % colors.count])
  }
  private func adaptiveColor(_ hex: String) -> Color {
    guard colorScheme == .dark, let value = UInt32(hex.dropFirst(), radix: 16) else { return Color(chartHex: hex) }
    // Built-in marks gain lightness in dark mode. Custom RGB choices remain exact.
    return Color(.sRGB, red: Double((value >> 16) & 255) / 255 * 0.65 + 0.35,
      green: Double((value >> 8) & 255) / 255 * 0.65 + 0.35,
      blue: Double(value & 255) / 255 * 0.65 + 0.35, opacity: 1)
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
    case .horizontalBar, .lollipop: return T("Frecuencia")
    case .boxplot: return ""
    default: return xName
    }
  }
  private var yAxisTitle: String {
    if configuration.yLabel.isEmpty == false { return configuration.yLabel }
    switch configuration.kind {
    case .histogram, .verticalBar: return T("Frecuencia")
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
        x: .value(L("Variable"), 1), yStart: .value(L("Bigote inferior"), summary.lower),
        yEnd: .value(L("Bigote superior"), summary.upper)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(lineWidth))).foregroundStyle(color)
      RectangleMark(
        xStart: .value(L("Inicio"), 0.8), xEnd: .value(L("Fin"), 1.2),
        yStart: .value(L("Q1"), summary.q1), yEnd: .value(L("Q3"), summary.q3)
      )
      .foregroundStyle(color.opacity(0.24))
      RuleMark(
        xStart: .value(L("Inicio"), 0.8), xEnd: .value(L("Fin"), 1.2),
        y: .value(L("Mediana"), summary.median)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(max(2, lineWidth)))).foregroundStyle(color)
      RuleMark(
        xStart: .value(L("Inicio"), 0.9), xEnd: .value(L("Fin"), 1.1),
        y: .value(L("Bigote inferior"), summary.lower)
      )
      .lineStyle(StrokeStyle(lineWidth: CGFloat(lineWidth))).foregroundStyle(color)
      RuleMark(
        xStart: .value(L("Inicio"), 0.9), xEnd: .value(L("Fin"), 1.1),
        y: .value(L("Bigote superior"), summary.upper)
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
      L("Boxplot: Q1 \(summary.q1), mediana \(summary.median), Q3 \(summary.q3), bigotes \(summary.lower) y \(summary.upper), \(summary.outliers) candidatos fuera de los bigotes")
    )
  }
}
