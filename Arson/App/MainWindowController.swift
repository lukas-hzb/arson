import AppKit
import Combine
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    nonisolated private static let toolbarIdentifier = NSToolbar.Identifier("ArsonMainToolbar")
    nonisolated private static let addPresetIdentifier = NSToolbarItem.Identifier(
        "ArsonAddPreset"
    )
    nonisolated private static let duplicatePresetIdentifier = NSToolbarItem.Identifier(
        "ArsonDuplicatePreset"
    )
    nonisolated private static let deletePresetIdentifier = NSToolbarItem.Identifier(
        "ArsonDeletePreset"
    )

    private let model: AppModel
    private let selection: PresetSelection
    private let sidebarViewController: PresetSidebarViewController
    private let presetUndoManager = UndoManager()
    private var observations: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model

        let selection = PresetSelection(selectedID: model.store.presets.first?.id)
        self.selection = selection

        let sidebarViewController = PresetSidebarViewController(
            model: model,
            selection: selection
        )
        self.sidebarViewController = sidebarViewController

        let detailViewController = NSHostingController(
            rootView: MainView(selection: selection)
                .environmentObject(model)
        )
        detailViewController.view.setAccessibilityLabel(String(localized: "sidebar.presets"))

        let splitViewController = NSSplitViewController()
        splitViewController.splitView.isVertical = true

        let sidebarItem = NSSplitViewItem(
            sidebarWithViewController: sidebarViewController
        )
        sidebarItem.minimumThickness = 190
        sidebarItem.maximumThickness = 320
        sidebarItem.preferredThicknessFraction = 230.0 / 920.0
        sidebarItem.canCollapse = true
        sidebarItem.canCollapseFromWindowResize = true
        sidebarItem.allowsFullHeightLayout = true

        let detailItem = NSSplitViewItem(viewController: detailViewController)
        detailItem.minimumThickness = 500

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(detailItem)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .unifiedTitleAndToolbar,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = splitViewController
        window.title = "Arson"
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.contentMinSize = NSSize(width: 720, height: 480)
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("ArsonMainWindow")
        window.setAccessibilityLabel("Arson")

        super.init(window: window)

        sidebarViewController.actionDelegate = self
        configureToolbar(for: window)
        observeModel()
        updateWindowState()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var undoManager: UndoManager? {
        presetUndoManager
    }

    private func configureToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
    }

    private func observeModel() {
        Publishers.CombineLatest(model.store.$presets, selection.$selectedID)
            .sink { [weak self] _, _ in
                self?.updateWindowState()
            }
            .store(in: &observations)
    }

    private func updateWindowState() {
        if let selectedID = selection.selectedID,
           let preset = model.store.presets.first(where: { $0.id == selectedID }) {
            window?.title = preset.name.isEmpty
                ? String(localized: "preset.untitled")
                : preset.name
        } else {
            window?.title = "Arson"
        }
        window?.toolbar?.validateVisibleItems()
    }

    @objc private func addPreset(_ sender: Any?) {
        selection.selectedID = model.store.addPreset()
    }

    @objc private func duplicateSelectedPreset(_ sender: Any?) {
        guard let selectedID = selection.selectedID else { return }
        duplicatePreset(selectedID)
    }

    @objc private func deleteSelectedPreset(_ sender: Any?) {
        guard let selectedID = selection.selectedID else { return }
        deletePreset(selectedID)
    }

    private func duplicatePreset(_ presetID: UUID) {
        selection.selectedID = model.store.duplicate(presetID)
    }

    private func deletePreset(_ presetID: UUID) {
        guard let index = model.store.presets.firstIndex(where: { $0.id == presetID }) else {
            return
        }

        let nextSelection: UUID?
        if index + 1 < model.store.presets.count {
            nextSelection = model.store.presets[index + 1].id
        } else if index > 0 {
            nextSelection = model.store.presets[index - 1].id
        } else {
            nextSelection = nil
        }

        model.store.delete(presetID, undoManager: presetUndoManager)
        selection.selectedID = nextSelection
    }
}

extension MainWindowController: PresetSidebarActionDelegate {
    func sidebarRequestedDuplicate(_ presetID: UUID) {
        duplicatePreset(presetID)
    }

    func sidebarRequestedDelete(_ presetID: UUID) {
        deletePreset(presetID)
    }
}

extension MainWindowController: NSToolbarDelegate {
    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            Self.addPresetIdentifier,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            Self.duplicatePresetIdentifier,
            Self.deletePresetIdentifier
        ]
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            Self.addPresetIdentifier,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            Self.duplicatePresetIdentifier,
            Self.deletePresetIdentifier
        ]
    }

    nonisolated func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        MainActor.assumeIsolated {
            switch itemIdentifier {
            case Self.addPresetIdentifier:
                return makeToolbarItem(
                    identifier: itemIdentifier,
                    label: String(localized: "action.addPreset"),
                    symbolName: "plus",
                    action: #selector(addPreset(_:))
                )

            case Self.duplicatePresetIdentifier:
                return makeToolbarItem(
                    identifier: itemIdentifier,
                    label: String(localized: "action.duplicate"),
                    symbolName: "doc.on.doc",
                    action: #selector(duplicateSelectedPreset(_:))
                )

            case Self.deletePresetIdentifier:
                return makeToolbarItem(
                    identifier: itemIdentifier,
                    label: String(localized: "action.delete"),
                    symbolName: "trash",
                    action: #selector(deleteSelectedPreset(_:))
                )

            default:
                return nil
            }
        }
    }

    private func makeToolbarItem(
        identifier: NSToolbarItem.Identifier,
        label: String,
        symbolName: String,
        action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = item.label
        item.toolTip = item.label
        item.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: item.label
        )
        item.target = self
        item.action = action
        item.isBordered = true
        return item
    }

}

extension MainWindowController: NSToolbarItemValidation, NSMenuItemValidation {
    nonisolated func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        MainActor.assumeIsolated {
            switch item.itemIdentifier {
            case Self.duplicatePresetIdentifier, Self.deletePresetIdentifier:
                return selection.selectedID != nil
            default:
                return true
            }
        }
    }

    nonisolated func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(duplicateSelectedPreset(_:)), #selector(deleteSelectedPreset(_:)):
            return MainActor.assumeIsolated { selection.selectedID != nil }
        default:
            return true
        }
    }
}
