// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "VAPULA", defaultLocalization: "es", platforms: [.macOS(.v14)],
  products: [
    .executable(name: "VAPULA", targets: ["VapulaApp"]),
    .library(name: "VapulaCore", targets: ["VapulaCore"]),
  ],
  dependencies: [.package(url: "https://github.com/duckdb/duckdb-swift.git", exact: "1.1.3")],
  targets: [
    .target(name: "VapulaCore"),
    .target(name: "VapulaStatistics", dependencies: ["VapulaCore"]),
    .target(
      name: "VapulaData",
      dependencies: [
        "VapulaCore", "VapulaStatistics", .product(name: "DuckDB", package: "duckdb-swift"),
      ]),
    .target(name: "VapulaReports", dependencies: ["VapulaCore"]),
    .executableTarget(
      name: "VapulaApp",
      dependencies: ["VapulaCore", "VapulaData", "VapulaStatistics", "VapulaReports"],
      resources: [.process("Resources")],
      swiftSettings: [
        .defaultIsolation(MainActor.self), .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]),
    .testTarget(
      name: "VapulaTests",
      dependencies: ["VapulaCore", "VapulaData", "VapulaStatistics", "VapulaReports"],
      resources: [.copy("Fixtures")]),
  ], swiftLanguageModes: [.v6]
)
