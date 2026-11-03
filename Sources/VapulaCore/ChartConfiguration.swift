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

  /// Exact RGB input validation, separate from defensive normalization of old projects.
  public static func validHex(_ input: String) -> String? {
    let hex = input.hasPrefix("#") ? String(input.dropFirst()) : input
    guard hex.utf8.count == 6,
      hex.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
    else { return nil }
    return "#" + hex.uppercased()
  }

  public var hasValidColor: Bool { palette != .custom || Self.validHex(customColorHex) != nil }

  public static func contrastRatio(_ first: String, _ second: String) -> Double? {
    func luminance(_ input: String) -> Double? {
      guard let hex = validHex(input), let rgb = UInt32(hex.dropFirst(), radix: 16) else { return nil }
      func linear(_ byte: UInt32) -> Double {
        let value = Double(byte) / 255
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
      }
      return 0.2126 * linear((rgb >> 16) & 255) + 0.7152 * linear((rgb >> 8) & 255) + 0.0722 * linear(rgb & 255)
    }
    guard let a = luminance(first), let b = luminance(second) else { return nil }
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
  }

  /// Bounds settings read from an editable project before using them in UI/query work.
  public func normalized() -> Self {
    var result = self
    result.binCount = min(100, max(5, binCount))
    result.pointSize = pointSize.isFinite ? min(140, max(8, pointSize)) : 36
    result.lineWidth = lineWidth.isFinite ? min(6, max(0.5, lineWidth)) : 2
    result.customColorHex = Self.validHex(customColorHex) ?? "#256A8A"
    result.title = String(title.prefix(180))
    result.xLabel = String(xLabel.prefix(120))
    result.yLabel = String(yLabel.prefix(120))
    return result
  }
}
