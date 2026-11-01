import Foundation

public enum ChartKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case histogram, verticalBar, horizontalBar, scatter, line, area, boxplot, lollipop
  public var id: Self { self }
}
public enum ChartPalette: String, Codable, CaseIterable, Identifiable, Sendable {
  case graphite, ocean, forest, plum, spectrum, custom
  public var id: Self { self }
}
public enum ChartPointShape: String, Codable, CaseIterable, Identifiable, Sendable {
  case circle, square, diamond, triangle
  public var id: Self { self }
}

/// Presentation choices only. Dataset names and query provenance remain separate.
public struct ChartConfiguration: Codable, Equatable, Sendable {
  public var kind: ChartKind = .histogram
  public var palette: ChartPalette = .ocean
  public var customColorHex = "#256A8A"
  public var showGrid = true
  public var pointSize: Double = 36
  public var lineWidth: Double = 2
  public var binCount = 20
  public var title = ""
  public var xLabel = ""
  public var yLabel = ""
  public var pointShape: ChartPointShape = .circle
  public var showPoints = true

  public init() {}

  /// Bounds settings read from an editable project before using them in UI/query work.
  public func normalized() -> Self {
    var result = self
    result.binCount = min(100, max(5, binCount))
    result.pointSize = pointSize.isFinite ? min(140, max(8, pointSize)) : 36
    result.lineWidth = lineWidth.isFinite ? min(6, max(0.5, lineWidth)) : 2
    let hex = customColorHex.hasPrefix("#") ? String(customColorHex.dropFirst()) : customColorHex
    result.customColorHex =
      hex.count == 6 && UInt32(hex, radix: 16) != nil
      ? "#" + hex.uppercased() : "#256A8A"
    result.title = String(title.prefix(180))
    result.xLabel = String(xLabel.prefix(120))
    result.yLabel = String(yLabel.prefix(120))
    return result
  }
}
