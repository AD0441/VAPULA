import AppKit
import VapulaCore

extension Workspace {
  func draftKey(nodeID: UUID, datasetID: UUID?) -> InspectorDraftKey? {
    project.map { InspectorDraftKey(projectID: $0.id, nodeID: nodeID, datasetID: datasetID) }
  }
  func recordDraft(_ draft: InspectorDraft?, for key: InspectorDraftKey?) {
    guard let key, project?.id == key.projectID else { return }
    inspectorDrafts[key] = draft
  }
  func discardDraft(for key: InspectorDraftKey) {
    inspectorDrafts[key] = nil; inspectorRevision += 1
  }
  func confirmDiscardDrafts() -> Bool {
    guard !inspectorDrafts.isEmpty else { return true }
    let alert = NSAlert()
    alert.messageText = L("Hay borradores sin ejecutar")
    alert.informativeText = L("Formularios editados en esta sesión: \(inspectorDrafts.count). Vuelve al inspector para aplicarlos o descártalos para salir del proyecto. Las versiones y resultados guardados se conservan.")
    alert.addButton(withTitle: L("Volver al proyecto"))
    alert.addButton(withTitle: L("Descartar borradores"))
    guard alert.runModal() == .alertSecondButtonReturn else { return false }
    inspectorDrafts.removeAll(); inspectorRevision += 1; return true
  }
}
