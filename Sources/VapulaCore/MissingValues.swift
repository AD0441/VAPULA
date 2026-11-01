import Foundation

public struct MissingPolicy: Codable, Sendable, Equatable {
  public var blankText: Bool
  public var nonFiniteNumbers: Bool
  public init(blankText: Bool = true, nonFiniteNumbers: Bool = true) {
    self.blankText = blankText; self.nonFiniteNumbers = nonFiniteNumbers
  }
}
public enum MissingAction: Codable, Sendable, Equatable {
  case dropRows, dropColumns, mean, median, mode, constant(String)
  public var title: String {
    switch self {
    case .dropRows: "Eliminar filas con ausentes"
    case .dropColumns: "Retirar columnas con ausentes"
    case .mean: "Completar con la media"
    case .median: "Completar con la mediana"
    case .mode: "Completar con la moda"
    case .constant: "Completar con un valor indicado"
    }
  }
}
public struct MissingImpact: Sendable, Equatable {
  public var datasetID: UUID
  public var counts: [String: Int]
  public var affectedRows: Int
  public var totalRows: Int
  public var affectedCells: Int { counts.values.reduce(0, +) }
  public init(datasetID: UUID, counts: [String: Int], affectedRows: Int, totalRows: Int) {
    self.datasetID = datasetID; self.counts = counts; self.affectedRows = affectedRows; self.totalRows = totalRows
  }
}
