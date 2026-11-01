import Foundation
import Testing
import VapulaCore
import VapulaStatistics

struct Reference: Decodable {
  var absoluteTolerance: Double
  var relativeTolerance: Double
  var paired: [PairCase]
  var welch: [WelchCase]
  var student: [StudentCase]
  var quantiles: [QuantileCase]
  struct PairCase: Decodable, Sendable {
    var name: String
    var x: [Double]
    var y: [Double]
    var expected: [String: Double]
  }
  struct WelchCase: Decodable, Sendable {
    var a: [Double]
    var b: [Double]
    var alpha: Double
    var expected: [String: Double]
  }
  struct StudentCase: Decodable, Sendable {
    var df: Double
    var t: Double
    var p: Double
  }
  struct QuantileCase: Decodable, Sendable {
    var df: Double
    var p: Double
    var value: Double
  }
  static func load() throws -> Self {
    let url = try #require(
      Bundle.module.url(
        forResource: "statistical-reference", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }
}
func close(_ actual: Double, _ expected: Double, absolute: Double = 1e-9, relative: Double = 1e-8)
  -> Bool
{ abs(actual - expected) <= absolute + relative * abs(expected) }
struct StatisticsTests {
  @Test func descriptiveCorrelationsAndOLSMatchSciPy() throws {
    let references = try Reference.load()
    var errors: [String: Double] = [:]
    for c in references.paired {
      var actual = try Statistics.describe(c.x.map(Optional.some)).metrics
      actual["pearson"] = try Statistics.pearson(c.x, c.y)
      actual["spearman"] = try Statistics.spearman(c.x, c.y)
      actual.merge(try Statistics.regression(c.x, c.y)) { _, new in new }
      for (key, expected) in c.expected {
        let value = try #require(actual[key])
        let group =
          ["mean", "sample_variance", "q1", "median", "q3"].contains(key)
          ? "descriptive" : ["pearson", "spearman"].contains(key) ? key : "ols"
        errors[group] = max(errors[group] ?? 0, abs(value - expected))
        #expect(close(value, expected), "\(c.name) / \(key): actual \(value), expected \(expected)")
      }
    }
    try recordNumericalErrors(errors, suffix: "paired")
  }
  @Test func welchMatchesIndependentReference() throws {
    var errors: [String: Double] = [:]
    for c in try Reference.load().welch {
      let actual = try Statistics.welch(c.a, c.b, alpha: c.alpha)
      for (key, expected) in c.expected {
        let value = try #require(actual[key])
        errors["welch"] = max(errors["welch"] ?? 0, abs(value - expected))
        #expect(close(value, expected), "Welch \(key): actual \(value), expected \(expected)")
      }
    }
    try recordNumericalErrors(errors, suffix: "welch")
  }
  @Test func studentDistributionAndQuantilesMatchSciPy() throws {
    let refs = try Reference.load()
    var errors: [String: Double] = [:]
    for c in refs.student {
      let p = try Statistics.studentTwoSided(c.t, df: c.df)
      errors["student_probability"] = max(errors["student_probability"] ?? 0, abs(p - c.p))
      #expect(close(p, c.p, absolute: 1e-14, relative: 1e-9), "t=\(c.t), df=\(c.df)")
    }
    for c in refs.quantiles {
      let q = try Statistics.studentQuantile(c.p, df: c.df)
      errors["student_quantile"] = max(errors["student_quantile"] ?? 0, abs(q - c.value))
      #expect(close(q, c.value), "quantile p=\(c.p), df=\(c.df)")
    }
    try recordNumericalErrors(errors, suffix: "student")
  }
  @Test func nullsAndNonfiniteAreExcludedExplicitly() throws {
    let summary = try Statistics.describe([1, 2, nil, .nan, .infinity, -.infinity, 3])
    #expect(summary.n == 3)
    #expect(summary.missing == 4)
    #expect(summary.mean == 2)
    #expect(summary.variance == 1)
  }
  @Test func oneObservationDoesNotPretendToHaveSampleVariance() throws {
    let summary = try Statistics.describe([5])
    #expect(summary.variance == nil)
    #expect(summary.median == 5)
  }
  @Test(arguments: [[], [Double?.none], [Double?.some(.nan)]])
  func noFiniteObservationsFails(_ values: [Double?]) {
    #expect(throws: VapulaError.self) { try Statistics.describe(values) }
  }
  @Test func constantsAndIncorrectPairLengthsFail() {
    #expect(throws: VapulaError.self) { try Statistics.pearson([1, 1, 1], [2, 3, 4]) }
    #expect(throws: VapulaError.self) { try Statistics.pearson([1, 2], [2, 3, 4]) }
    #expect(throws: VapulaError.self) { try Statistics.regression([1, 2], [2, 3]) }
    #expect(throws: VapulaError.self) { try Statistics.welch([1, 1], [2, 2]) }
    #expect(throws: VapulaError.self) { try Statistics.welch([1], [2, 3]) }
  }
  @Test func ranksUseAverageTies() { #expect(Statistics.ranks([4, 1, 1, 9]) == [3, 1.5, 1.5, 4]) }
  @Test func extremeFiniteInputsRefuseOverflow() {
    #expect(throws: VapulaError.self) { try Statistics.describe([1e308, -1e308]) }
  }
}

func recordNumericalErrors(_ errors: [String: Double], suffix: String) throws {
  if let prefix = ProcessInfo.processInfo.environment["VAPULA_NUMERICAL_OUTPUT"] {
    let data = try JSONSerialization.data(
      withJSONObject: errors, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: prefix + "-" + suffix + ".json"), options: .atomic)
  }
  print("Observed maximum absolute numerical differences: \(errors)")
}
