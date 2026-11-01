import AppKit
import SwiftUI
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
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .frame(minWidth: 1060, minHeight: 700)
    }
    .defaultSize(width: 1280, height: 820)
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Nuevo proyecto…", action: workspace.createProject).keyboardShortcut("n")
        Button("Abrir proyecto…", action: workspace.openProject).keyboardShortcut("o")
        Divider()
        Button("Importar datos…", action: workspace.chooseImport).keyboardShortcut("i").disabled(
          workspace.project == nil || workspace.busy)
        Button("Cerrar proyecto", action: workspace.closeProject).disabled(
          workspace.project == nil || workspace.busy)
      }
      CommandMenu("Datos") {
        Button("Calcular perfil", action: workspace.profile).disabled(
          workspace.dataset == nil || workspace.busy)
        Button("Exportar CSV…") { workspace.exportData(parquet: false) }.disabled(
          workspace.dataset == nil || workspace.busy)
        Button("Exportar Parquet…") { workspace.exportData(parquet: true) }.disabled(
          workspace.dataset == nil || workspace.busy)
        Button("Exportar informe…") { workspace.exportReport(csv: false) }.keyboardShortcut("e")
          .disabled(workspace.project == nil || workspace.busy)
      }
      CommandMenu("Flujo") {
        Button("Guardar flujo", action: workspace.persistWorkflow).keyboardShortcut("s").disabled(workspace.project == nil || workspace.busy)
        Button("Ejecutar pasos pendientes") { workspace.executeWorkflowNode() }.keyboardShortcut("r").disabled(workspace.project == nil || workspace.busy)
        Button("Ejecutar paso seleccionado") { if let id = workspace.workflowNodeID { workspace.executeWorkflowNode(id) } }.keyboardShortcut(.return).disabled(workspace.workflowNodeID == nil || workspace.busy)
        Button("Ajustar al lienzo") { workspace.workflowFitRequest += 1 }.keyboardShortcut("0")
        Divider()
        Button("Deshacer cambio del flujo", action: workspace.undoWorkflow).keyboardShortcut("z").disabled(!workspace.workflowUndoAvailable || workspace.busy)
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
      guard workspace.workflowUnsaved else { return .terminateNow }
      Task { @MainActor in
        do { try await workspace.savePendingWorkflow(); sender.reply(toApplicationShouldTerminate: true) }
        catch { workspace.error = error.localizedDescription; sender.reply(toApplicationShouldTerminate: false) }
      }
      return .terminateLater
    }
    let alert = NSAlert()
    alert.messageText = "Hay una operación en curso"
    alert.informativeText =
      "Espera a que termine o pulsa Cancelar antes de cerrar VAPULA. Los pasos completados ya están guardados."
    alert.addButton(withTitle: "Volver")
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
      Picker("Idioma", selection: $language) {
        Text("Español").tag("es")
        Text("English").tag("en")
      }
      Picker("Apariencia", selection: $appearance) {
        Text("Sistema").tag("system")
        Text("Claro").tag("light")
        Text("Oscuro").tag("dark")
      }
      LabeledContent("Procesamiento", value: "100 % local")
      Text(
        "Los proyectos guardan automáticamente cada operación completada. No hay telemetría ni servicios de actualización."
      ).foregroundStyle(.secondary)
      Text("Creado por Sebastián Pastén F.").font(.footnote)
    }.formStyle(.grouped).padding().frame(width: 470, height: 300)
  }
}
