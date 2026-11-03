import AppKit
import SwiftUI
import VapulaCore

/// Native table for a dynamic schema. Only a single database page lives in SwiftUI.
struct DataGrid: NSViewRepresentable {
  let columns: [ColumnDefinition]
  let rows: [DataRow]
  var onSort: ((String) -> Void)?
  var onEdit: ((DataRow, String) -> Void)?
  var onSelection: (([DataRow]) -> Void)?
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSScrollView()
    scroll.hasHorizontalScroller = true
    scroll.hasVerticalScroller = true
    let table = NSTableView()
    table.usesAlternatingRowBackgroundColors = true
    table.rowHeight = 26
    table.columnAutoresizingStyle = .noColumnAutoresizing
    table.dataSource = context.coordinator
    table.delegate = context.coordinator
    table.target = context.coordinator
    table.doubleAction = #selector(Coordinator.editClickedCell(_:))
    table.allowsMultipleSelection = true
    table.setAccessibilityLabel(L("Tabla de datos, página de hasta 100 filas"))
    scroll.documentView = table
    context.coordinator.table = table
    return scroll
  }
  func updateNSView(_ view: NSScrollView, context: Context) {
    let coordinator = context.coordinator
    let changed = coordinator.rows != rows || coordinator.columns != columns
    coordinator.rows = rows
    coordinator.onSort = onSort
    coordinator.onEdit = onEdit
    coordinator.onSelection = onSelection
    guard let table = coordinator.table else { return }
    table.setAccessibilityLabel(L("Tabla de datos, página de hasta 100 filas"))
    if coordinator.columns != columns {
      for c in table.tableColumns { table.removeTableColumn(c) }
      for c in columns {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(c.name))
        column.title = c.name
        column.width = 150
        column.minWidth = 80
        if onSort != nil {
          column.sortDescriptorPrototype = NSSortDescriptor(key: c.name, ascending: true)
        }
        table.addTableColumn(column)
      }
      coordinator.columns = columns
    }
    if changed {
      coordinator.reloading = true
      table.reloadData()
      coordinator.reloading = false
    }
  }
  final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    weak var table: NSTableView?
    var columns: [ColumnDefinition] = []
    var rows: [DataRow] = []
    var onSort: ((String) -> Void)?
    var onEdit: ((DataRow, String) -> Void)?
    var onSelection: (([DataRow]) -> Void)?
    var reloading = false
    @objc func editClickedCell(_ table: NSTableView) {
      let row = table.clickedRow; let col = table.clickedColumn
      guard rows.indices.contains(row), columns.indices.contains(col) else { return }
      onEdit?(rows[row], columns[col].name)
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
      guard !reloading, let table else { return }
      onSelection?(table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0] : nil })
    }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int)
      -> NSView?
    {
      guard let name = tableColumn?.identifier.rawValue,
        let index = columns.firstIndex(where: { $0.name == name }), rows.indices.contains(row),
        rows[row].cells.indices.contains(index)
      else { return nil }
      let id = NSUserInterfaceItemIdentifier("cell")
      let cell =
        (tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView)
        ?? NSTableCellView()
      if cell.textField == nil {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
          label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 7),
          label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -7),
          label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        cell.identifier = id
      }
      let value = rows[row].cells[index]
      cell.textField?.stringValue = value ?? "∅"
      cell.textField?.textColor = value == nil ? .secondaryLabelColor : .labelColor
      cell.textField?.toolTip = value ?? "NULL"
      cell.textField?.setAccessibilityLabel(L("\(name): \(value ?? "NULL")"))
      return cell
    }
    func tableView(
      _ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]
    ) {
      if let key = tableView.sortDescriptors.first?.key { onSort?(key) }
    }
  }
}
