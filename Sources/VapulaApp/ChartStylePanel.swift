import AppKit
import SwiftUI
import VapulaCore

struct ChartStylePanel: View {
  @Binding var configuration: ChartConfiguration
  let isBusy: Bool
  let save: () -> Void
  var saveTitle = "Guardar estilo"
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        Text(L("Diseño")).font(.headline)
        VStack(alignment: .leading, spacing: 10) {
          Text(L("Color")).font(.subheadline.weight(.semibold))
          Picker(L("Paleta"), selection: $configuration.palette) {
            ForEach(ChartPalette.allCases) { palette in
              Text(T(palette.title)).tag(palette)
            }
          }
          ColorPicker(L("Personalizado"), selection: customColor, supportsOpacity: false)
          if configuration.palette == .custom {
            TextField(L("Color HEX"), text: $configuration.customColorHex)
              .textFieldStyle(.roundedBorder)
              .help(L("Color hexadecimal de seis dígitos, por ejemplo #256A8A"))
            if !configuration.hasValidColor {
              Label(L("Escribe seis dígitos HEX, por ejemplo #256A8A. El color aún no se ha aplicado."), systemImage: "exclamationmark.circle")
                .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            } else if let ratio = ChartConfiguration.contrastRatio(configuration.customColorHex, colorScheme == .dark ? "#1C1C1E" : "#FFFFFF"), min(ratio, ChartConfiguration.contrastRatio(configuration.customColorHex, "#FFFFFF") ?? 0) < 3 {
              Label(L("Este color tiene poco contraste en pantalla o en el informe PDF claro. Elige uno más visible o cambia de paleta."), systemImage: "eye")
                .font(.caption).foregroundStyle(WorkbenchInk.warning).fixedSize(horizontal: false, vertical: true)
            }
          }
          if configuration.palette != .custom {
            HStack(spacing: 8) {
              ForEach(Array(configuration.palette.hexColors.prefix(5)), id: \.self) { hex in
                Circle().fill(Color(chartHex: hex)).frame(width: 15, height: 15)
              }
            }.accessibilityHidden(true)
          }
        }
        VStack(alignment: .leading, spacing: 10) {
          Text(L("Títulos y ejes")).font(.subheadline.weight(.semibold))
          TextField(L("Título del gráfico"), text: $configuration.title)
          TextField(L("Etiqueta X (automática si está vacía)"), text: $configuration.xLabel)
          TextField(L("Etiqueta Y (automática si está vacía)"), text: $configuration.yLabel)
          Toggle(L("Mostrar cuadrícula"), isOn: $configuration.showGrid)
        }.textFieldStyle(.roundedBorder)
        if configuration.kind == .histogram {
          VStack(alignment: .leading, spacing: 8) {
            Stepper(
              L("Intervalos: \(configuration.binCount)"), value: $configuration.binCount, in: 5...100)
            Text(L("Pulsa Actualizar datos después de cambiar los intervalos."))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        if configuration.kind == .scatter || configuration.kind == .line
          || configuration.kind == .area || configuration.kind == .lollipop
        {
          VStack(alignment: .leading, spacing: 10) {
            Text(L("Marcas")).font(.subheadline.weight(.semibold))
            Picker(L("Forma"), selection: $configuration.pointShape) {
              ForEach(ChartPointShape.allCases) { shape in
                Text(T(shape.title)).tag(shape)
              }
            }
            LabeledContent(
              L("Tamaño"),
              value: configuration.pointSize.formatted(.number.precision(.fractionLength(0))))
            Slider(value: $configuration.pointSize, in: 8...140).accessibilityLabel(L("Tamaño de las marcas"))
            if configuration.kind == .line || configuration.kind == .area {
              Toggle(L("Mostrar puntos"), isOn: $configuration.showPoints)
            }
          }
        }
        if configuration.kind == .line || configuration.kind == .area
          || configuration.kind == .boxplot || configuration.kind == .lollipop
        {
          VStack(alignment: .leading, spacing: 8) {
            LabeledContent(
              L("Grosor"),
              value: configuration.lineWidth.formatted(.number.precision(.fractionLength(1))))
            Slider(value: $configuration.lineWidth, in: 0.5...6).accessibilityLabel(L("Grosor del trazo"))
          }
        }
        Divider()
        Button(T(saveTitle), action: save).buttonStyle(.borderedProminent).disabled(!configuration.hasValidColor)
        Text(
          L("Se guarda con esta versión del conjunto. Cambiar el diseño no modifica los datos ni los resultados estadísticos.")
        )
        .font(.caption).foregroundStyle(.secondary)
      }.padding(.leading, 18).padding(.vertical, 4)
    }.disabled(isBusy)
  }

  private var customColor: Binding<Color> {
    Binding(
      get: { Color(chartHex: configuration.customColorHex) },
      set: { color in
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return }
        guard rgb.redComponent.isFinite, rgb.greenComponent.isFinite, rgb.blueComponent.isFinite
        else { return }
        func byte(_ value: CGFloat) -> Int { Int((min(1, max(0, value)) * 255).rounded()) }
        configuration.customColorHex = String(
          format: "#%02X%02X%02X",
          byte(rgb.redComponent),
          byte(rgb.greenComponent),
          byte(rgb.blueComponent))
        configuration.palette = .custom
      })
  }
}

extension ChartPalette {
  var title: String {
    switch self {
    case .graphite: "Grafito"
    case .ocean: "Océano"
    case .forest: "Bosque"
    case .plum: "Ciruela"
    case .spectrum: "Espectro"
    case .custom: "Personalizado"
    }
  }
  var hexColors: [String] {
    switch self {
    case .graphite: ["#30363B", "#58636D", "#7B8995", "#A4AEB6", "#68747D"]
    case .ocean: ["#256A8A", "#328BA4", "#63A9B6", "#506C9B", "#6A94BC"]
    case .forest: ["#35765A", "#549477", "#82AC72", "#5F8568", "#94B58B"]
    case .plum: ["#795589", "#A474A3", "#BE8EAE", "#846B9F", "#A58CC0"]
    case .spectrum: ["#247BA0", "#C86836", "#43815D", "#9869AB", "#B48B25"]
    case .custom: []
    }
  }
}
extension ChartPointShape {
  var title: String {
    switch self {
    case .circle: "Círculo"
    case .square: "Cuadrado"
    case .diamond: "Rombo"
    case .triangle: "Triángulo"
    }
  }
}
extension Color {
  init(chartHex: String) {
    let hex = chartHex.hasPrefix("#") ? String(chartHex.dropFirst()) : chartHex
    let value = UInt32(hex, radix: 16) ?? 0x256A8A
    self.init(
      .sRGB, red: Double((value >> 16) & 255) / 255,
      green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
  }
}
