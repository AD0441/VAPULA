import Foundation
import Testing
import VapulaCore
import VapulaStatistics

private struct ExpandedReference: Decodable {
  var absoluteTolerance: Double
  var relativeTolerance: Double
  var oneSample: [OneSampleCase]
  var paired: [PairedCase]
  var anova: [ANOVACase]
  var mannWhitney: [MannWhitneyCase]
  var chiSquare: [ChiSquareCase]

  struct OneSampleCase: Decodable {
    var name: String
    var values: [Double]
    var mean: Double
    var alpha: Double
    var expected: [String: Double]
  }
  struct PairedCase: Decodable {
    var name: String
    var x: [Double]
    var y: [Double]
    var alpha: Double
    var expected: [String: Double]
  }
  struct ANOVACase: Decodable {
    var name: String
    var groups: [[Double]]
    var expected: [String: Double]
  }
  struct MannWhitneyCase: Decodable {
    var name: String
    var a: [Double]
    var b: [Double]
    var expected: [String: Double]
  }
  struct ChiSquareCase: Decodable {
    var name: String
    var counts: [[Int]]
    var expected: [String: Double]
  }

  static func load() throws -> Self {
    let url = try #require(
      Bundle.module.url(
        forResource: "expanded-statistical-reference", withExtension: "json",
        subdirectory: "Fixtures"))
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }
}

struct ExpandedStatisticsTests {
  @Test func oneSampleTMatchesIndependentSciPyReferences() throws {
    let reference = try ExpandedReference.load()
    var maximumError = 0.0
    for c in reference.oneSample {
      let actual = try Statistics.oneSampleT(c.values, mean: c.mean, alpha: c.alpha)
      maximumError = max(
        maximumError,
        try compareExpandedMetrics(actual, c.expected, name: c.name, reference: reference))
    }
    try recordExpandedError(maximumError, method: "one_sample_t")
  }

  @Test func pairedTMatchesIndependentSciPyReferences() throws {
    let reference = try ExpandedReference.load()
    var maximumError = 0.0
    for c in reference.paired {
      let actual = try Statistics.pairedT(c.x, c.y, alpha: c.alpha)
      maximumError = max(
        maximumError,
        try compareExpandedMetrics(actual, c.expected, name: c.name, reference: reference))
    }
    try recordExpandedError(maximumError, method: "paired_t")
  }

  @Test func classicalANOVAMatchesIndependentSciPyReferences() throws {
    let reference = try ExpandedReference.load()
    var maximumError = 0.0
    for c in reference.anova {
      let actual = try Statistics.oneWayANOVA(c.groups)
      maximumError = max(
        maximumError,
        try compareExpandedMetrics(actual, c.expected, name: c.name, reference: reference))
    }
    try recordExpandedError(maximumError, method: "one_way_anova")
  }

  @Test func mannWhitneyMatchesTieCorrectedAsymptoticSciPyReferences() throws {
    let reference = try ExpandedReference.load()
    var maximumError = 0.0
    for c in reference.mannWhitney {
      let actual = try Statistics.mannWhitney(c.a, c.b)
      maximumError = max(
        maximumError,
        try compareExpandedMetrics(actual, c.expected, name: c.name, reference: reference))
    }
    try recordExpandedError(maximumError, method: "mann_whitney")
  }

  @Test func chiSquareMatchesUncorrectedSciPyReferencesAndSparseDiagnostics() throws {
    let reference = try ExpandedReference.load()
    var maximumError = 0.0
    for c in reference.chiSquare {
      let actual = try Statistics.chiSquare(c.counts)
      maximumError = max(
        maximumError,
        try compareExpandedMetrics(actual, c.expected, name: c.name, reference: reference))
    }
    try recordExpandedError(maximumError, method: "chi_square")
  }

  @Test(arguments: [0.0, -0.1, 1.0, Double.nan, Double.infinity])
  func tTestsRejectInvalidAlpha(_ alpha: Double) {
    #expect(throws: VapulaError.self) {
      try Statistics.oneSampleT([1, 2, 3], alpha: alpha)
    }
    #expect(throws: VapulaError.self) {
      try Statistics.pairedT([1, 2, 4], [0, 2, 3], alpha: alpha)
    }
  }

  @Test(arguments: [[], [1.0], [2.0, 2.0], [Double.nan, 1.0], [Double.infinity, 2.0]])
  func oneSampleTRejectsInsufficientNonfiniteAndConstantData(_ sample: [Double]) {
    #expect(throws: VapulaError.self) { try Statistics.oneSampleT(sample) }
  }

  @Test func pairedTRejectsUnmatchedOrDegenerateDifferences() {
    #expect(throws: VapulaError.self) { try Statistics.pairedT([1, 2], [1]) }
    #expect(throws: VapulaError.self) { try Statistics.pairedT([1, 2], [0, 1]) }
    #expect(throws: VapulaError.self) { try Statistics.pairedT([1, .nan], [0, 2]) }
    #expect(throws: VapulaError.self) {
      try Statistics.pairedT([1e308, -1e308], [-1e308, 1e308])
    }
  }

  @Test func oneSampleTRejectsInvalidReferenceAndOverflow() {
    #expect(throws: VapulaError.self) { try Statistics.oneSampleT([1, 2], mean: .nan) }
    #expect(throws: VapulaError.self) { try Statistics.oneSampleT([1e308, -1e308]) }
  }

  @Test func ANOVARejectsMissingGroupsNonfiniteDataAndZeroWithinVariation() {
    #expect(throws: VapulaError.self) { try Statistics.oneWayANOVA([[1, 2]]) }
    #expect(throws: VapulaError.self) { try Statistics.oneWayANOVA([[1, 2], []]) }
    #expect(throws: VapulaError.self) { try Statistics.oneWayANOVA([[1], [2, 3]]) }
    #expect(throws: VapulaError.self) { try Statistics.oneWayANOVA([[1, 1], [2, 2]]) }
    #expect(throws: VapulaError.self) { try Statistics.oneWayANOVA([[1, .nan], [2, 3]]) }
  }

  @Test func mannWhitneyRejectsNonfiniteAndAllTiedSamples() {
    #expect(throws: VapulaError.self) { try Statistics.mannWhitney([], [1, 2]) }
    #expect(throws: VapulaError.self) { try Statistics.mannWhitney([1, .infinity], [2, 3]) }
    #expect(throws: VapulaError.self) { try Statistics.mannWhitney([2, 2], [2, 2, 2]) }
  }

  @Test func mannWhitneyDirectionAndTwoSidedProbabilityRemainConsistent() throws {
    let a = [1.0, 2, 2, 5, 6]
    let b = [2.0, 4, 7, 8]
    let ab = try Statistics.mannWhitney(a, b)
    let ba = try Statistics.mannWhitney(b, a)
    let ua = try #require(ab["u_a"])
    let reversedU = try #require(ba["u_a"])
    #expect(ua + reversedU == Double(a.count * b.count))
    #expect(ab["p_two_sided"] == ba["p_two_sided"])
    let effect = try #require(ab["rank_biserial_a_minus_b"])
    let reversedEffect = try #require(ba["rank_biserial_a_minus_b"])
    #expect(abs(effect + reversedEffect) < 1e-14)
  }

  @Test func chiSquareRejectsMalformedNegativeEmptyMarginalAndHugeCounts() {
    for counts in [
      [[1, 2]], [[1], [2]], [[1, 2], [3]], [[1, -1], [2, 3]],
      [[0, 0], [1, 2]], [[1, 0], [2, 0]], [[0, 0], [0, 0]],
      [[Int.max, 1], [1, 2]],
    ] {
      #expect(throws: VapulaError.self) { try Statistics.chiSquare(counts) }
    }
  }

  @Test func independenceReturnsZeroChiSquareAndUnitProbability() throws {
    let result = try Statistics.chiSquare([[20, 20], [20, 20]])
    #expect(result["chi_square"] == 0)
    #expect(result["p_value"] == 1)
    #expect(result["cramers_v"] == 0)
  }
}

private func compareExpandedMetrics(
  _ actual: [String: Double], _ expected: [String: Double], name: String,
  reference: ExpandedReference
) throws -> Double {
  var maximumError = 0.0
  #expect(actual.values.allSatisfy { $0.isFinite }, "\(name) must not expose NaN or Inf")
  for (key, target) in expected {
    let value = try #require(actual[key], "Missing \(key) for \(name)")
    let error = abs(value - target)
    maximumError = max(maximumError, error)
    #expect(
      error <= reference.absoluteTolerance + reference.relativeTolerance * abs(target),
      "\(name) / \(key): actual \(value), expected \(target)")
  }
  return maximumError
}

private func recordExpandedError(_ error: Double, method: String) throws {
  if let prefix = ProcessInfo.processInfo.environment["VAPULA_NUMERICAL_OUTPUT"] {
    let data = try JSONSerialization.data(
      withJSONObject: [method: error], options: [.prettyPrinted, .sortedKeys])
    try data.write(
      to: URL(fileURLWithPath: prefix + "-expanded-" + method + ".json"), options: .atomic)
  }
  print("Observed expanded numerical difference: \(method)=\(error)")
}
