import Foundation

/// Identifies the application producing an export, independently of project history.
public struct ReportSoftware: Equatable, Sendable {
  public let version: String?
  public let build: String?

  public init(version: String?, build: String?) {
    func nonempty(_ value: String?) -> String? {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
      return value
    }
    self.version = nonempty(version)
    self.build = nonempty(build)
  }

  public static var current: Self {
    let bundle = Bundle.main
    // A SwiftPM test runner or another host is not the VAPULA application.
    guard bundle.bundleIdentifier == "cl.sebastianpasten.VAPULA" else {
      return Self(version: nil, build: nil)
    }
    return Self(version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
      build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
  }

  public var label: String {
    guard let version else { return "VAPULA (desarrollo; versión del bundle no disponible)" }
    return "VAPULA \(version) (build \(build ?? "no disponible"))"
  }
}
