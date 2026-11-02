import Foundation

public struct CastApproval: Codable, Sendable, Equatable {
  public let datasetID: UUID
  public let column: String
  public let type: PhysicalType
  public let newNulls: Int
  public init(datasetID: UUID, column: String, type: PhysicalType, newNulls: Int) {
    self.datasetID = datasetID; self.column = column; self.type = type; self.newNulls = newNulls
  }
}

public struct CastImpact: Sendable, Equatable {
  public let approval: CastApproval
  public let existingNulls: Int
  public let examples: [String]
  public var newNulls: Int { approval.newNulls }
  public init(approval: CastApproval, existingNulls: Int, examples: [String]) {
    self.approval = approval; self.existingNulls = existingNulls; self.examples = examples
  }
}
