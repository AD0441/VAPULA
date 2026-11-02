import Foundation

public struct InspectorDraftKey: Hashable, Sendable {
  public let projectID: UUID
  public let nodeID: UUID
  public let datasetID: UUID?
  public init(projectID: UUID, nodeID: UUID, datasetID: UUID?) {
    self.projectID = projectID; self.nodeID = nodeID; self.datasetID = datasetID
  }
}
public struct PreparationDraft: Equatable, Sendable {
  public var column = "", action = "filter", value = "", newName = "", group = "", lower = "", upper = ""
  public var comparison = Comparison.equal
  public var physicalType = PhysicalType.number
  public var arithmetic = Arithmetic.multiply
  public var aggregate = Aggregate.mean
  public var selectedColumns = Set<String>(), duplicateKeys = Set<String>()
  public var rangeEnabled = false
  public init() {}
}
public struct StatisticsDraft: Equatable, Sendable {
  public var method = AnalysisMethod.descriptive
  public var x = "", y = "", group = "", groupA = "", groupB = "", referenceMean = "0"
  public var alpha = 0.05
  public init() {}
}
public struct MissingDraft: Equatable, Sendable {
  public var selected = Set<String>()
  public var method = "mean", constant = ""
  public var blanks = true, nonfinite = true
  public init() {}
}
public enum InspectorDraft: Equatable, Sendable {
  case preparation(PreparationDraft), statistics(StatisticsDraft), missing(MissingDraft)
  case chart(WorkflowChart), report(Set<UUID>)
}
/// Session-only raw form state. Executable tasks and saved results remain separate.
public struct InspectorDraftStore: Sendable {
  private var values: [InspectorDraftKey: InspectorDraft] = [:]
  public init() {}
  public var count: Int { values.count }
  public var isEmpty: Bool { values.isEmpty }
  public subscript(_ key: InspectorDraftKey) -> InspectorDraft? {
    get { values[key] }
    set { values[key] = newValue }
  }
  public mutating func removeAll() { values.removeAll() }
}
