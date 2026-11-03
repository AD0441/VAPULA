import Foundation

public enum InterfaceLanguage: String, Sendable { case spanish = "es", english = "en" }

/// Translates interface templates while keeping interpolated user content verbatim.
public struct InterfaceText: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, Sendable {
  public let key: String
  public let arguments: [String]
  public init(stringLiteral value: String) { key = value; arguments = [] }
  public init(stringInterpolation: StringInterpolation) {
    key = stringInterpolation.key; arguments = stringInterpolation.arguments
  }
  public struct StringInterpolation: StringInterpolationProtocol {
    var key = ""
    var arguments: [String] = []
    public init(literalCapacity: Int, interpolationCount: Int) {
      key.reserveCapacity(literalCapacity); arguments.reserveCapacity(interpolationCount)
    }
    public mutating func appendLiteral(_ literal: String) { key += literal }
    public mutating func appendInterpolation<T>(_ value: T) { key += "%@"; arguments.append(String(describing: value)) }
  }
  static let english: [String: String] = {
    guard let url = Bundle.module.url(forResource: "Interface.en", withExtension: "json"),
      let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode([String: String].self, from: data)
    else { return [:] }
    return value
  }()
  static let spanish: [String: String] = {
    var result: [String: String] = [:]
    for key in english.keys.sorted() { result[english[key] ?? key] = key }
    return result
  }()
  public func rendered(in language: InterfaceLanguage) -> String {
    let template = language == .english ? Self.english[key] ?? key : key
    return Self.fill(template, arguments: arguments) ?? Self.fill(key, arguments: arguments) ?? key
  }
  private static func fill(_ template: String, arguments: [String]) -> String? {
    let parts = template.components(separatedBy: "%@")
    guard parts.count == arguments.count + 1 else { return nil }
    return parts.enumerated().map { index, part in index == 0 ? part : arguments[index - 1] + part }.joined()
  }
  /// Use only for known application labels/messages, never for names, cell contents or titles.
  public static func label(_ key: String, in language: InterfaceLanguage) -> String {
    language == .english ? english[key] ?? key : english[key] != nil ? key : spanish[key] ?? key
  }
  /// Localizes saved diagnostics at the presentation boundary, without rewriting project data.
  public static func diagnostic(_ message: String, in language: InterfaceLanguage) -> String {
    let catalog = language == .english ? english : spanish
    if let exact = catalog[message] { return exact }
    for key in catalog.keys.sorted(by: { $0.count > $1.count }) where key.contains("%@") {
      let pieces = key.components(separatedBy: "%@")
      guard let first = pieces.first, message.hasPrefix(first),
        !first.isEmpty || pieces.contains(where: { $0.count > 12 && message.contains($0) }) else { continue }
      let pattern = "^" + pieces.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "(.*?)") + "$"
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
        let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message))
      else { continue }
      let arguments = (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: message).map { String(message[$0]) } }
      return fill(catalog[key] ?? key, arguments: arguments) ?? message
    }
    if message.contains("\n") {
      return message.components(separatedBy: "\n").map { diagnostic($0, in: language) }.joined(separator: "\n")
    }
    return message
  }
}
