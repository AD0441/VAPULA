import SwiftUI
import VapulaCore

struct WorkbenchCanvas: View {
  let workspace: Workspace
  @State private var zoom: CGFloat = 1
  @State private var pan = CGSize.zero
  @GestureState private var panTranslation = CGSize.zero
  @GestureState private var stepDrag: StepDrag?
  @State private var hasFitted = false
  private var isDragging: Bool { stepDrag != nil || panTranslation != .zero }

  var body: some View {
    GeometryReader { geometry in
      let viewport = CGSize(width: pan.width + panTranslation.width, height: pan.height + panTranslation.height)
      let steps = displayedSteps
      ZStack(alignment: .topLeading) {
        WorkbenchDotGrid(zoom: zoom, pan: viewport)
          .contentShape(Rectangle())
          .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($panTranslation) { value, translation, _ in translation = value.translation }
            .onEnded { value in
              pan.width += value.translation.width
              pan.height += value.translation.height
            })
        WorkbenchWires(steps: steps, selected: stepDrag?.id ?? workspace.workflowNodeID, zoom: zoom, pan: viewport)
          .allowsHitTesting(false).accessibilityHidden(true)
        ForEach(steps) { step in
          MovableWorkflowStep(step: step, workspace: workspace, isDragging: isDragging, drag: dragGesture(for: step.id))
            .scaleEffect(zoom)
            .position(x: step.position.x * zoom + viewport.width, y: step.position.y * zoom + viewport.height)
        }
        if workspace.workflow.nodes.isEmpty {
          ContentUnavailableView(L("Tu flujo empieza aquí"), systemImage: "square.stack.3d.up",
            description: Text(L("Importa un CSV, TSV o Parquet local y conecta tu primer paso.")))
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        VStack {
          HStack {
            Label(workspace.project?.name ?? "Mi flujo", systemImage: "point.3.connected.trianglepath.dotted")
              .font(.system(size: 11, weight: .medium))
            Spacer()
            Text(L("\(workspace.workflow.nodes.count) pasos")).font(.system(size: 10.5)).foregroundStyle(.secondary)
          }.padding(.horizontal, 18).padding(.top, 15)
          if workspace.workflowConnection != nil {
            HStack {
              Text(L("Selecciona la entrada de otra caja para conectar.")).font(.system(size: 11))
              Button(L("Cancelar")) { workspace.workflowConnection = nil }.controlSize(.small)
            }.padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding(.top, 7)
          }
          Spacer()
          HStack {
            Text(L("Arrastra las cajas · conecta con + · inspecciona al seleccionar")).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 0) {
              Button { zoom = max(0.35, zoom - 0.1) } label: { Image(systemName: "minus").frame(width: 28, height: 27) }.help(L("Alejar")).accessibilityLabel(L("Alejar"))
              Text(L("\(Int(zoom * 100)) %")).font(.system(size: 10.5).monospacedDigit()).frame(width: 43)
              Button { zoom = min(1.6, zoom + 0.1) } label: { Image(systemName: "plus").frame(width: 28, height: 27) }.help(L("Acercar")).accessibilityLabel(L("Acercar"))
              Divider().frame(height: 13)
              Button { fit(in: geometry.size) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 29, height: 27) }.help(L("Ajustar el flujo · ⌘0")).accessibilityLabel(L("Ajustar al lienzo"))
            }.buttonStyle(.plain).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
              .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.quaternary))
              .disabled(isDragging)
          }.padding(14)
        }.frame(width: geometry.size.width, height: geometry.size.height)
      }
      .clipped()
      .onAppear { if !hasFitted { fit(in: geometry.size); if zoom < 0.75 { zoom = 0.9; focus(in: geometry.size) }; hasFitted = true } }
      .onChange(of: workspace.workflowFitRequest) { fit(in: geometry.size) }
      .onChange(of: geometry.size) { _, _ in focus(in: geometry.size) }
      .onChange(of: workspace.workflowFocusID) { focus(in: geometry.size) }
    }
  }

  private struct StepDrag {
    let id: UUID
    let translation: CGSize
  }

  private var displayedSteps: [WorkflowNode] {
    var steps = workspace.workflow.nodes
    if let stepDrag, let index = steps.firstIndex(where: { $0.id == stepDrag.id }) {
      steps[index].position = translated(steps[index].position, by: stepDrag.translation)
    }
    return steps
  }

  private func translated(_ origin: WorkflowPoint, by translation: CGSize) -> WorkflowPoint {
    WorkflowPoint(origin.x + translation.width / zoom, origin.y + translation.height / zoom)
  }

  private func dragGesture(for id: UUID) -> some Gesture {
    // The card moves and scales inside the window. Measuring in its own
    // coordinates feeds that movement back into the next drag event.
    DragGesture(minimumDistance: 5, coordinateSpace: .global)
      .updating($stepDrag) { value, drag, _ in
        guard !workspace.busy else { return }
        drag = StepDrag(id: id, translation: value.translation)
      }
      .onEnded { value in
        guard !workspace.busy, let step = workspace.workflow.nodes.first(where: { $0.id == id }) else { return }
        let destination = translated(step.position, by: value.translation)
        guard destination != step.position else { return }
        workspace.rememberWorkflow()
        workspace.workflowNodeID = id
        workspace.moveWorkflowNode(id, x: destination.x, y: destination.y)
        workspace.persistWorkflow()
      }
  }

  private func focus(in size: CGSize) {
    guard !isDragging, let id = workspace.workflowFocusID ?? workspace.workflowNodeID,
      let step = workspace.workflow.nodes.first(where: { $0.id == id }) else { return }
    let point = CGPoint(x: step.position.x * zoom + pan.width, y: step.position.y * zoom + pan.height)
    let x = min(max(point.x, 125), max(125, size.width - 125))
    let y = min(max(point.y, 135), max(135, size.height - 125))
    pan.width += x - point.x; pan.height += y - point.y
  }
  private func fit(in size: CGSize) {
    guard !isDragging else { return }
    guard !workspace.workflow.nodes.isEmpty else { zoom = 1; pan = .zero; return }
    let points = workspace.workflow.nodes.map(\.position)
    let minX = (points.map(\.x).min() ?? 0) - 110
    let maxX = (points.map(\.x).max() ?? 800) + 110
    let minY = (points.map(\.y).min() ?? 0) - 86
    let maxY = (points.map(\.y).max() ?? 300) + 90
    let available = CGSize(width: max(200, size.width - 38), height: max(160, size.height - 104))
    zoom = max(0.35, min(1.05, min(available.width / (maxX - minX), available.height / (maxY - minY))))
    pan = CGSize(width: (size.width - (maxX - minX) * zoom) / 2 - minX * zoom,
      height: 49 + (available.height - (maxY - minY) * zoom) / 2 - minY * zoom)
  }
}
private struct WorkbenchDotGrid: View {
  let zoom: CGFloat
  let pan: CGSize
  var body: some View {
    Canvas { context, size in
      let spacing = max(12, 24 * zoom)
      let offsetX = pan.width.truncatingRemainder(dividingBy: spacing)
      let offsetY = pan.height.truncatingRemainder(dividingBy: spacing)
      for x in stride(from: offsetX, through: size.width, by: spacing) {
        for y in stride(from: offsetY, through: size.height, by: spacing) {
          context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.1)), with: .color(.primary.opacity(0.13)))
        }
      }
    }.background(Color(nsColor: .textBackgroundColor))
  }
}
private struct WorkbenchWires: View {
  let steps: [WorkflowNode]
  let selected: UUID?
  let zoom: CGFloat
  let pan: CGSize
  var body: some View {
    Canvas { context, _ in
      let byID = Dictionary(uniqueKeysWithValues: steps.map { ($0.id, $0) })
      for step in steps {
        for parentID in step.inputs {
          guard let parent = byID[parentID] else { continue }
          let a = CGPoint(x: (parent.position.x + 96) * zoom + pan.width, y: parent.position.y * zoom + pan.height)
          let b = CGPoint(x: (step.position.x - 96) * zoom + pan.width, y: step.position.y * zoom + pan.height)
          let reach = max(28, abs(b.x - a.x) * 0.5)
          var path = Path(); path.move(to: a)
          path.addCurve(to: b, control1: CGPoint(x: a.x + reach, y: a.y), control2: CGPoint(x: b.x - reach, y: b.y))
          let active = selected == step.id || selected == parentID
          context.stroke(path, with: .color(active ? WorkbenchInk.accent.opacity(0.7) : .secondary.opacity(0.45)), style: StrokeStyle(lineWidth: active ? 2 : 1.5, lineCap: .round))
          var arrow = Path(); arrow.move(to: CGPoint(x: b.x - 6, y: b.y - 3)); arrow.addLine(to: b); arrow.addLine(to: CGPoint(x: b.x - 6, y: b.y + 3))
          context.stroke(arrow, with: .color(active ? WorkbenchInk.accent : .secondary.opacity(0.6)), lineWidth: 1.4)
        }
      }
    }
  }
}
private struct MovableWorkflowStep<Drag: Gesture>: View {
  let step: WorkflowNode
  let workspace: Workspace
  let isDragging: Bool
  let drag: Drag
  var body: some View {
    ZStack {
      Button { if !isDragging { workspace.selectWorkflowNode(step.id) } } label: {
        WorkbenchNodeCard(node: step, workspace: workspace)
      }.buttonStyle(.plain).disabled(workspace.busy)
        .accessibilityLabel(step.displayName)
        .accessibilityValue(T(step.lastError != nil ? "Revisar" : !step.task.configured ? "Configurar" : step.dirty ? "Por ejecutar" : "Listo"))
        .accessibilityHint(L("Sus opciones y resultados aparecerán aquí."))
        .accessibilityAddTraits(workspace.workflowNodeID == step.id ? [.isSelected] : [])
        .accessibilityRemoveTraits(workspace.workflowNodeID == step.id ? [] : [.isSelected])
        .simultaneousGesture(drag, including: workspace.busy ? .none : .all)
      if step.kind != .data {
        Button { workspace.connectWorkflow(to: step.id) } label: {
          Circle().fill(Color(nsColor: .controlBackgroundColor)).overlay(Circle().stroke(workspace.workflowConnection == nil ? Color.secondary : WorkbenchInk.accent, lineWidth: 1.5)).frame(width: 9, height: 9).padding(8)
        }.buttonStyle(.plain).position(x: 0, y: 68).help(L("Entrada de \(step.displayName)")).accessibilityLabel(L("Conectar entrada de \(step.displayName)"))
      }
      if step.kind != .report {
        Button { workspace.workflowConnection = step.id; workspace.status = L("Selecciona la entrada de la caja que quieres conectar.") } label: {
          Circle().fill(step.kind.ink).frame(width: 9, height: 9).padding(8)
        }.buttonStyle(.plain).position(x: 192, y: 68).help(L("Conectar salida")).accessibilityLabel(L("Conectar salida de \(step.displayName)"))
      }
      if !step.kind.compatibleNext.isEmpty {
        Menu {
          ForEach(step.kind.compatibleNext, id: \.self) { kind in
            Button { workspace.addWorkflowNode(kind, after: step.id) } label: { Label(T(kind.title), systemImage: kind.symbol) }
          }
        } label: { Image(systemName: "plus").font(.system(size: 10, weight: .semibold)).frame(width: 22, height: 22) }
          .disabled(workspace.busy)
          .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
          .background(.regularMaterial, in: Circle()).overlay(Circle().strokeBorder(.quaternary))
          .position(x: 170, y: 146).help(L("Añadir el siguiente paso compatible")).accessibilityLabel(L("Añadir el siguiente paso compatible"))
      }
    }.frame(width: 192, height: 136)
      .contextMenu {
        Button(L("Ejecutar paso")) { workspace.executeWorkflowNode(step.id) }
        ForEach(step.kind.compatibleNext, id: \.self) { kind in
          Button(L("Añadir \(T(kind.title).lowercased())")) { workspace.addWorkflowNode(kind, after: step.id) }
        }
        Divider()
        Button(L("Retirar rama"), role: .destructive) { workspace.removeWorkflowBranch(step.id) }
      }
  }
}
extension WorkflowKind {
  var ink: Color {
    switch self {
    case .data: Color(red: 0.28, green: 0.43, blue: 0.56)
    case .prepare, .missing: Color(red: 0.55, green: 0.42, blue: 0.24)
    case .analyze: Color(red: 0.48, green: 0.37, blue: 0.54)
    case .chart: WorkbenchInk.accent
    case .quality: Color(red: 0.52, green: 0.44, blue: 0.22)
    case .report: Color.secondary
    }
  }
}
