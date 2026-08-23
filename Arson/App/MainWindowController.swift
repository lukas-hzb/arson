import AppKit
import Combine
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    nonisolated private static let toolbarIdentifier = NSToolbar.Identifier("ArsonMainToolbar")
    nonisolated private static let addPresetIdentifier = NSToolbarItem.Identifier("ArsonAddPreset")
    nonisolated private static let moreActionsIdentifier = NSToolbarItem.Identifier("ArsonPresetActions")

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

    private func makeActionsMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "action.more"))

        let duplicate = NSMenuItem(
            title: String(localized: "action.duplicate"),
            action: #selector(duplicateSelectedPreset(_:)),
            keyEquivalent: ""
        )
        duplicate.target = self
        menu.addItem(duplicate)

        menu.addItem(.separator())

        let delete = NSMenuItem(
            title: String(localized: "action.delete"),
            action: #selector(deleteSelectedPreset(_:)),
            keyEquivalent: ""
        )
        delete.target = self
        menu.addItem(delete)

        return menu
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
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            Self.addPresetIdentifier,
            Self.moreActionsIdentifier
        ]
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .flexibleSpace,
            .toggleSidebar,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            Self.addPresetIdentifier,
            Self.moreActionsIdentifier
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
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.label = String(localized: "action.addPreset")
                item.paletteLabel = item.label
                item.toolTip = item.label
                item.image = NSImage(
                    systemSymbolName: "plus",
                    accessibilityDescription: item.label
                )
                item.target = self
                item.action = #selector(addPreset(_:))
                item.isBordered = true
                return item

            case Self.moreActionsIdentifier:
                let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
                item.label = String(localized: "action.more")
                item.paletteLabel = item.label
                item.toolTip = item.label
                item.image = NSImage(
                    systemSymbolName: "ellipsis.circle",
                    accessibilityDescription: item.label
                )
                item.menu = makeActionsMenu()
                item.showsIndicator = true
                item.isBordered = true
                return item

            default:
                return nil
            }
        }
    }
}

extension MainWindowController: NSToolbarItemValidation, NSMenuItemValidation {
    nonisolated func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        MainActor.assumeIsolated {
            switch item.itemIdentifier {
            case Self.addPresetIdentifier:
                return true
            case Self.moreActionsIdentifier:
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
