import Foundation
import Testing
@testable import VapulaCore

struct InterfacePolishTests {
  @Test(arguments: ["#256a8a", "256A8A", "#FFFFFF", "000000"])
  func validRGBIsCanonical(_ input: String) {
    #expect(ChartConfiguration.validHex(input)?.hasPrefix("#") == true)
    #expect(ChartConfiguration.validHex(input)?.count == 7)
  }
  @Test(arguments: ["", "#FFF", "#00000000", "+12345", "#GG1234", " #123456", "１２３４５６"])
  func invalidRGBDoesNotBecomeAnAppliedColor(_ input: String) {
    var style = ChartConfiguration(); style.palette = .custom; style.customColorHex = input
    #expect(!style.hasValidColor)
    #expect(style.customColorHex == input)
    #expect(style.normalized().customColorHex == "#256A8A")
  }
  @Test func contrastMatchesBlackWhiteAndRejectsInvalidInput() {
    #expect(abs((ChartConfiguration.contrastRatio("#000000", "#FFFFFF") ?? 0) - 21) < 1e-12)
    #expect(ChartConfiguration.contrastRatio("#FFFFFF", "#FFFFFF") == 1)
    #expect(ChartConfiguration.contrastRatio("#bad", "#FFFFFF") == nil)
    #expect((ChartConfiguration.contrastRatio("#386659", "#FFFFFF") ?? 0) >= 4.5)
  }
  @Test func translationPreservesInterpolatedUserContentAndCanSwitchBack() {
    let userValue = "Mi columna %@ 50% ‘café’"
    let message: InterfaceText = "Origen: \(userValue)"
    #expect(message.rendered(in: .english) == "Source: " + userValue)
    #expect(message.rendered(in: .spanish) == "Origen: " + userValue)
    #expect(InterfaceText.diagnostic("Hay cambios sin aplicar en «\(userValue)». Abre su inspector y aplícalos, o descarta ese borrador, antes de ejecutar esta rama.", in: .english).contains(userValue))
    #expect(InterfaceText.diagnostic("Unrecognized source value: \(userValue)", in: .english) == "Unrecognized source value: \(userValue)")
    #expect(InterfaceText.diagnostic("Unknown column: \(userValue)", in: .spanish) == "Columna desconocida: " + userValue)
    let diagnostic = "No se pudo leer «\(userValue)». No se ha añadido una versión incompleta.\nColumna: \(userValue)."
    let translated = InterfaceText.diagnostic(diagnostic, in: .english)
    #expect(translated == "Could not read “\(userValue)”. No incomplete version was added.\nColumn: \(userValue).")
    #expect(InterfaceText.diagnostic(translated, in: .spanish) == diagnostic)
  }
  @Test func translatedTemplatesNeverDropOrAddSubstitutions() {
    #expect(InterfaceText.english.count > 300)
    for (key, translation) in InterfaceText.english {
      #expect(key.components(separatedBy: "%@").count == translation.components(separatedBy: "%@").count, "Template: \(key)")
      #expect(key.isEmpty || !translation.isEmpty)
    }
  }
  @Test func keyboardConnectionsExcludeDescendantsAndIncompatibleFamilies() throws {
    let datasetID = UUID()
    let source = WorkflowNode(name: "Source", task: .data(datasetID), position: WorkflowPoint(0, 0))
    let first = WorkflowNode(name: "First", task: .prepare(nil), inputs: [source.id], position: WorkflowPoint(200, 0))
    let child = WorkflowNode(name: "Child", task: .prepare(nil), inputs: [first.id], position: WorkflowPoint(400, 0))
    let analysis = WorkflowNode(name: "Analysis", task: .analyze(nil), inputs: [source.id], position: WorkflowPoint(200, 180))
    let report = WorkflowNode(name: "Report", task: .report, inputs: [analysis.id], position: WorkflowPoint(400, 180))
    var flow = DataWorkflow(); flow.nodes = [source, first, child, analysis, report]
    #expect(flow.connectionCandidates(to: first.id).map(\.id) == [source.id])
    #expect(flow.connectionCandidates(to: report.id).map(\.id) == [analysis.id])
    #expect(flow.connectionCandidates(to: source.id).isEmpty)
    for candidate in flow.connectionCandidates(to: child.id) {
      var proposed = flow
      proposed.nodes[2].inputs = [candidate.id]
      try proposed.validate(datasetIDs: [datasetID], resultIDs: [])
    }
  }
}
