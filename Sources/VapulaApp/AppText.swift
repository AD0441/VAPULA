import Foundation
import Observation
import VapulaCore

@Observable
final class InterfacePreferences {
  static let shared = InterfacePreferences()
  var language = InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "es") ?? .spanish
}
func L(_ message: InterfaceText) -> String { message.rendered(in: InterfacePreferences.shared.language) }
func T(_ key: String) -> String { InterfaceText.label(key, in: InterfacePreferences.shared.language) }
func D(_ message: String) -> String { InterfaceText.diagnostic(message, in: InterfacePreferences.shared.language) }

extension WorkflowNode {
  var displayName: String {
    // A user-supplied chart title or source filename is never a translation key.
    switch task {
    case .data: return name
    case .chart(let chart) where chart?.style.title.isEmpty == false: return name
    case .chart(let chart) where name == kind.title: return chart.map { T($0.style.kind.title) } ?? T(name)
    case .prepare(let operation) where name == operation?.displayTitle: return T(name)
    case .analyze(let specification) where name == specification?.method.title: return T(name)
    default: return name == kind.title ? T(name) : name
    }
  }
}
