import Foundation
import Testing
import VapulaCore

struct InspectorDraftsTests {
  @Test func draftsAreIsolatedByProjectNodeAndInputVersion() {
    let project = UUID(), node = UUID(), version = UUID()
    let key = InspectorDraftKey(projectID: project, nodeID: node, datasetID: version)
    var store = InspectorDraftStore()
    var preparation = PreparationDraft(); preparation.action = "derive"; preparation.value = "unfinished 1e-"
    var statistics = StatisticsDraft(); statistics.referenceMean = "not a number yet"
    store[key] = .preparation(preparation)
    let other = InspectorDraftKey(projectID: project, nodeID: UUID(), datasetID: version)
    store[other] = .statistics(statistics)
    #expect(store[key] == .preparation(preparation) && store[other] == .statistics(statistics))
    #expect(store[InspectorDraftKey(projectID: UUID(), nodeID: node, datasetID: version)] == nil)
    #expect(store[InspectorDraftKey(projectID: project, nodeID: node, datasetID: UUID())] == nil)
    store[key] = nil
    #expect(store.count == 1 && store[other] == .statistics(statistics))
    store.removeAll(); #expect(store.isEmpty)
  }
}
