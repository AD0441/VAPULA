import AppKit
import SwiftUI
import VapulaCore
import os

@main
struct VapulaApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @State private var workspace = Workspace()
  @AppStorage("language") private var language = "es"
  @AppStorage("appearance") private var appearance = "system"
  var body: some Scene {
    Window("VAPULA", id: "main") {
      ContentView(workspace: workspace)
        .onAppear { delegate.workspace = workspace }
        .environment(\.locale, Locale(identifier: language))
        .onChange(of: language) { _, value in
          InterfacePreferences.shared.language = InterfaceLanguage(rawValue: value) ?? .spanish
        }
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .frame(minWidth: 1060, minHeight: 700)
    }
    .defaultSize(width: 1280, height: 820)
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentMinSize)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button(L("Nuevo proyecto…"), action: workspace.createProject).keyboardShortcut("n")
        Button(L("Abrir proyecto…"), action: workspace.openProject).keyboardShortcut("o")
        Divider()
        Button(L("Importar datos…"), action: workspace.chooseImport).keyboardShortcut("i").disabled(
          workspace.project == nil || workspace.busy)
        Button(L("Cerrar proyecto"), action: workspace.closeProject).disabled(
          workspace.project == nil || workspace.busy)
      }
      CommandMenu(L("Datos")) {
        Button(L("Calcular perfil"), action: workspace.profile).disabled(
          workspace.dataset == nil || workspace.busy)
        Button(L("Exportar CSV…")) { workspace.exportData(parquet: false) }.disabled(
          workspace.dataset == nil || workspace.busy)
        Button(L("Exportar Parquet…")) { workspace.exportData(parquet: true) }.disabled(
          workspace.dataset == nil || workspace.busy)
        Button(L("Exportar informe…")) { workspace.requestReportExport() }.keyboardShortcut("e")
          .disabled(workspace.project == nil || workspace.busy)
      }
      CommandMenu(L("Flujo")) {
        Button(L("Ir a los pasos del flujo"), action: workspace.focusWorkflowSteps)
          .keyboardShortcut("l", modifiers: [.command, .option])
          .disabled(workspace.workflow.nodes.isEmpty || workspace.busy)
        Button(L("Paso anterior")) { workspace.selectAdjacentStep(-1) }
          .keyboardShortcut(.upArrow, modifiers: [.command, .option]).disabled(workspace.project == nil || workspace.busy)
        Button(L("Paso siguiente")) { workspace.selectAdjacentStep(1) }
          .keyboardShortcut(.downArrow, modifiers: [.command, .option]).disabled(workspace.project == nil || workspace.busy)
        Divider()
        Button(L("Guardar flujo"), action: workspace.persistWorkflow).keyboardShortcut("s").disabled(workspace.project == nil || workspace.busy)
        Button(L("Ejecutar pasos pendientes")) { workspace.executeWorkflowNode() }.keyboardShortcut("r").disabled(workspace.project == nil || workspace.busy)
        Button(L("Ejecutar paso seleccionado")) { if let id = workspace.workflowNodeID { workspace.executeWorkflowNode(id) } }.keyboardShortcut(.return).disabled(workspace.workflowNodeID == nil || workspace.busy)
        Button(L("Ajustar al lienzo")) { workspace.workflowFitRequest += 1 }.keyboardShortcut("0")
        Divider()
        Button(L("Deshacer cambio del flujo"), action: workspace.undoWorkflow).keyboardShortcut("z").disabled(!workspace.workflowUndoAvailable || workspace.busy)
      }
      CommandMenu(L("Paneles")) {
        Toggle(L("Biblioteca"), isOn: $workspace.workflowSidebar).keyboardShortcut("1", modifiers: [.command, .option])
        Toggle(L("Vista previa"), isOn: $workspace.workflowPreview).keyboardShortcut("2", modifiers: [.command, .option])
        Toggle(L("Inspector"), isOn: $workspace.workflowInspector).keyboardShortcut("3", modifiers: [.command, .option])
      }
    }
    Settings { SettingsView().environment(\.locale, Locale(identifier: language)) }
  }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
  weak var workspace: Workspace?
  func application(_ application: NSApplication, open urls: [URL]) {
    if let url = urls.first, let workspace, workspace.busy == false {
      workspace.openProject(at: url)
    }
  }
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    guard let workspace else { return .terminateNow }
    if !workspace.busy {
      guard workspace.confirmDiscardDrafts() else { return .terminateCancel }
      Task { @MainActor in
        do {
          try await workspace.savePendingWorkflow()
          await workspace.engine.close()
          sender.reply(toApplicationShouldTerminate: true)
        }
        catch { workspace.error = error.localizedDescription; sender.reply(toApplicationShouldTerminate: false) }
      }
      return .terminateLater
    }
    let alert = NSAlert()
    alert.messageText = L("Hay una operación en curso")
    alert.informativeText =
      L("Espera a que termine o pulsa Cancelar antes de cerrar VAPULA. Los pasos completados ya están guardados.")
    alert.addButton(withTitle: L("Volver"))
    alert.runModal()
    return .terminateCancel
  }
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    Logger(subsystem: "cl.sebastianpasten.VAPULA", category: "lifecycle").notice(
      "VAPULA started; no network services configured")
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
struct SettingsView: View {
  @AppStorage("language") private var language = "es"
  @AppStorage("appearance") private var appearance = "system"
  var body: some View {
    Form {
      Picker(L("Idioma"), selection: $language) {
        Text(L("Español")).tag("es")
        Text(L("English")).tag("en")
      }
      Picker(L("Apariencia"), selection: $appearance) {
        Text(L("Sistema")).tag("system")
        Text(L("Claro")).tag("light")
        Text(L("Oscuro")).tag("dark")
      }
      LabeledContent(L("Procesamiento"), value: "100 % local")
      Text(
        L("Los proyectos guardan automáticamente cada operación completada. No hay telemetría ni servicios de actualización.")
      ).foregroundStyle(.secondary)
      Text(L("Creado por Sebastián Pastén F.")).font(.footnote)
    }.formStyle(.grouped).padding().frame(width: 470, height: 300)
  }
}
