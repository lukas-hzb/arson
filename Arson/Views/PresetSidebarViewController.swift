@preconcurrency import AppKit
import Combine

@MainActor
protocol PresetSidebarActionDelegate: AnyObject {
    func sidebarRequestedDuplicate(_ presetID: UUID)
    func sidebarRequestedDelete(_ presetID: UUID)
}

@MainActor
final class PresetSidebarViewController: NSViewController {
    weak var actionDelegate: PresetSidebarActionDelegate?

    nonisolated private static let presetPasteboardType = NSPasteboard.PasteboardType(
        "de.lukasharzbecker.arson.preset"
    )

    private let model: AppModel
    private let store: PresetStore
    private let selection: PresetSelection
    private let tableView = NSTableView()
    private var displayedPresets: [Preset]
    private var observations: Set<AnyCancellable> = []

    init(model: AppModel, selection: PresetSelection) {
        self.model = model
        store = model.store
        self.selection = selection
        displayedPresets = model.store.presets
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = tableView

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("PresetColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowSizeStyle = .default
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([Self.presetPasteboardType])
        tableView.setDraggingSourceOperationMask(.move, forLocal: true)
        tableView.draggingDestinationFeedbackStyle = .sourceList
        tableView.menu = makeContextMenu()
        tableView.setAccessibilityLabel(String(localized: "sidebar.presets"))

        view = scrollView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        store.$presets
            .sink { [weak self] presets in
                self?.reloadPresets(with: presets)
            }
            .store(in: &observations)

        selection.$selectedID
            .removeDuplicates()
            .sink { [weak self] selectedID in
                self?.selectRow(for: selectedID)
            }
            .store(in: &observations)
    }

    private func reloadPresets(with presets: [Preset]) {
        displayedPresets = presets
        tableView.reloadData()
        selectRow(for: selection.selectedID)
    }

    private func selectRow(for presetID: UUID?) {
        guard let presetID,
              let row = displayedPresets.firstIndex(where: { $0.id == presetID }) else {
            tableView.deselectAll(nil)
            return
        }

        if tableView.selectedRow != row {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        tableView.scrollRowToVisible(row)
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }

    private func presetIDForContextMenu() -> UUID? {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard displayedPresets.indices.contains(row) else { return nil }
        return displayedPresets[row].id
    }

    @objc private func duplicateFromContextMenu(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? UUID else { return }
        actionDelegate?.sidebarRequestedDuplicate(presetID)
    }

    @objc private func deleteFromContextMenu(_ sender: NSMenuItem) {
        guard let presetID = sender.representedObject as? UUID else { return }
        actionDelegate?.sidebarRequestedDelete(presetID)
    }
}

extension PresetSidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
        MainActor.assumeIsolated { displayedPresets.count }
    }

    nonisolated func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        MainActor.assumeIsolated {
            guard displayedPresets.indices.contains(row) else { return nil }

            let identifier = NSUserInterfaceItemIdentifier("PresetSidebarCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self)
                as? PresetSidebarCellView ?? PresetSidebarCellView(identifier: identifier)
            let preset = displayedPresets[row]
            cell.configure(
                preset: preset,
                hasError: !model.validationMessages(for: preset).isEmpty
            )
            return cell
        }
    }

    nonisolated func tableViewSelectionDidChange(_ notification: Notification) {
        MainActor.assumeIsolated {
            let row = tableView.selectedRow
            guard displayedPresets.indices.contains(row) else {
                selection.selectedID = nil
                return
            }
            selection.selectedID = displayedPresets[row].id
        }
    }

    nonisolated func tableView(
        _ tableView: NSTableView,
        pasteboardWriterForRow row: Int
    ) -> (any NSPasteboardWriting)? {
        let presetID: String? = MainActor.assumeIsolated {
            guard displayedPresets.indices.contains(row) else { return nil }
            return displayedPresets[row].id.uuidString
        }
        guard let presetID else { return nil }
        let item = NSPasteboardItem()
        item.setString(presetID, forType: Self.presetPasteboardType)
        return item
    }

    nonisolated func tableView(
        _ tableView: NSTableView,
        validateDrop info: any NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        MainActor.assumeIsolated {
            guard dropOperation == .above,
                  info.draggingPasteboard.string(forType: Self.presetPasteboardType) != nil else {
                return []
            }
            return .move
        }
    }

    nonisolated func tableView(
        _ tableView: NSTableView,
        acceptDrop info: any NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        MainActor.assumeIsolated {
            guard dropOperation == .above,
                  let value = info.draggingPasteboard.string(forType: Self.presetPasteboardType),
                  let presetID = UUID(uuidString: value),
                  let source = store.presets.firstIndex(where: { $0.id == presetID }) else {
                return false
            }

            store.move(from: IndexSet(integer: source), to: row)
            selection.selectedID = presetID
            return true
        }
    }
}

extension PresetSidebarViewController: NSMenuDelegate {
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        let presetID: UUID? = MainActor.assumeIsolated {
            if tableView.clickedRow >= 0 {
                tableView.selectRowIndexes(
                    IndexSet(integer: tableView.clickedRow),
                    byExtendingSelection: false
                )
            }
            return presetIDForContextMenu()
        }

        menu.removeAllItems()
        guard let presetID else { return }

        let duplicate = NSMenuItem(
            title: String(localized: "action.duplicate"),
            action: #selector(duplicateFromContextMenu(_:)),
            keyEquivalent: ""
        )
        duplicate.target = self
        duplicate.representedObject = presetID
        menu.addItem(duplicate)

        menu.addItem(.separator())

        let delete = NSMenuItem(
            title: String(localized: "action.delete"),
            action: #selector(deleteFromContextMenu(_:)),
            keyEquivalent: ""
        )
        delete.target = self
        delete.representedObject = presetID
        menu.addItem(delete)
    }
}

@MainActor
private final class PresetSidebarCellView: NSTableCellView {
    private let presetImageView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let shortcutField = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier

        presetImageView.translatesAutoresizingMaskIntoConstraints = false
        presetImageView.setContentHuggingPriority(.required, for: .horizontal)
        presetImageView.setAccessibilityHidden(true)

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.lineBreakMode = .byTruncatingTail
        nameField.maximumNumberOfLines = 1
        nameField.identifier = NSUserInterfaceItemIdentifier("presetRowName")
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        shortcutField.translatesAutoresizingMaskIntoConstraints = false
        shortcutField.textColor = .secondaryLabelColor
        shortcutField.alignment = .right
        shortcutField.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(presetImageView)
        addSubview(nameField)
        addSubview(shortcutField)
        imageView = presetImageView
        textField = nameField

        NSLayoutConstraint.activate([
            presetImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            presetImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            presetImageView.widthAnchor.constraint(equalToConstant: 16),
            presetImageView.heightAnchor.constraint(equalToConstant: 16),

            nameField.leadingAnchor.constraint(equalTo: presetImageView.trailingAnchor, constant: 8),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),

            shortcutField.leadingAnchor.constraint(greaterThanOrEqualTo: nameField.trailingAnchor, constant: 8),
            shortcutField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            shortcutField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        shortcutField.font = nameField.font
        presetImageView.symbolConfiguration = nameField.font.map {
            NSImage.SymbolConfiguration(pointSize: $0.pointSize, weight: .regular)
        }
    }

    func configure(preset: Preset, hasError: Bool) {
        let name = preset.name.isEmpty ? String(localized: "preset.untitled") : preset.name
        nameField.stringValue = name
        shortcutField.stringValue = preset.shortcut?.displayValue ?? ""
        shortcutField.isHidden = preset.shortcut == nil

        let symbolName = hasError
            ? "exclamationmark.circle.fill"
            : PresetSidebarSymbol.name(for: preset)
        presetImageView.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )
        presetImageView.contentTintColor = hasError ? .systemOrange : nil

        setAccessibilityLabel(
            preset.shortcut.map { "\(name), \($0.displayValue)" } ?? name
        )
        setAccessibilityChildren([])
    }
}
