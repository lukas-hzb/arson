import AppKit
import Combine
import SwiftUI

@MainActor
final class MainWindowController: NSWindowController {
    nonisolated static let currentOnboardingVersion = 2
    nonisolated static let onboardingPreferenceKey = "completedOnboardingVersion"
    nonisolated private static let defaultContentSize = NSSize(width: 920, height: 620)
    nonisolated private static let minimumContentSize = NSSize(width: 720, height: 480)
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
    nonisolated private static let defaultToolbarItemIdentifiers: [NSToolbarItem.Identifier] = [
        .flexibleSpace,
        addPresetIdentifier,
        .toggleSidebar,
        .sidebarTrackingSeparator,
        .flexibleSpace,
        duplicatePresetIdentifier,
        deletePresetIdentifier
    ]
    nonisolated private static let presetMenuIdentifier = NSUserInterfaceItemIdentifier(
        "ArsonPresetMenu"
    )

    private let model: AppModel
    private let defaults: UserDefaults
    private let selection: PresetSelection
    private let sidebarViewController: PresetSidebarViewController
    private let splitViewController: NSSplitViewController
    private let contentContainerViewController: MainContentContainerViewController
    private let presetUndoManager = UndoManager()
    private var observations: Set<AnyCancellable> = []
    private var onboardingViewController: NSViewController?
    private(set) var isShowingOnboarding = false

    init(model: AppModel, defaults: UserDefaults = .standard) {
        self.model = model
        self.defaults = defaults

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
        sidebarItem.preferredThicknessFraction = 250.0 / 920.0
        sidebarItem.canCollapse = true
        sidebarItem.canCollapseFromWindowResize = true
        sidebarItem.allowsFullHeightLayout = true

        let detailItem = NSSplitViewItem(viewController: detailViewController)
        detailItem.minimumThickness = 500

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(detailItem)

        let contentContainerViewController = MainContentContainerViewController()
        contentContainerViewController.setContent(splitViewController, animated: false)

        self.splitViewController = splitViewController
        self.contentContainerViewController = contentContainerViewController

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
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
        window.contentViewController = contentContainerViewController
        window.title = "Arson"
        window.titleVisibility = .visible
        window.toolbarStyle = .unified
        window.contentMinSize = Self.minimumContentSize
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier("ArsonMainWindow")
        window.setAccessibilityLabel("Arson")

        super.init(window: window)

        sidebarViewController.actionDelegate = self
        configureToolbar(for: window)
        window.minSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: Self.minimumContentSize)
        ).size
        observeModel()
        updateWindowState(
            presets: model.store.presets,
            selectedID: selection.selectedID
        )
        if defaults.integer(forKey: Self.onboardingPreferenceKey)
            < Self.currentOnboardingVersion {
            showOnboarding(animated: false)
        }
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var undoManager: UndoManager? {
        presetUndoManager
    }

    func prepareForPresentation() {
        guard let window else { return }

        let contentSize = window.contentView?.bounds.size ?? window.contentLayoutRect.size
        let hasUsableSize = contentSize.width >= Self.minimumContentSize.width
            && contentSize.height >= Self.minimumContentSize.height

        let targetScreen = window.screen ?? NSScreen.main
        let visibleFrame = targetScreen?.visibleFrame
        let visibleIntersection = visibleFrame.map { window.frame.intersection($0) }
        let isMeaningfullyVisible = visibleIntersection.map {
            !$0.isNull && $0.width >= 160 && $0.height >= 120
        } ?? true

        guard !hasUsableSize || !isMeaningfullyVisible else { return }

        window.setContentSize(Self.defaultContentSize)
        window.center()
    }

    func showOnboarding(animated: Bool = true) {
        guard !isShowingOnboarding else { return }

        model.permissions.refresh()
        let onboardingViewController = NSHostingController(
            rootView: OnboardingView { [weak self] in
                self?.completeOnboarding()
            }
            .environmentObject(model)
        )
        onboardingViewController.view.setAccessibilityLabel(
            String(localized: "onboarding.title")
        )

        self.onboardingViewController = onboardingViewController
        isShowingOnboarding = true
        window?.title = "Arson"
        replaceToolbarItems(with: [.flexibleSpace])
        contentContainerViewController.setContent(
            onboardingViewController,
            animated: animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        window?.toolbar?.validateVisibleItems()
    }

    func completeOnboarding() {
        guard isShowingOnboarding else { return }

        defaults.set(
            Self.currentOnboardingVersion,
            forKey: Self.onboardingPreferenceKey
        )
        isShowingOnboarding = false
        replaceToolbarItems(with: Self.defaultToolbarItemIdentifiers)
        contentContainerViewController.setContent(
            splitViewController,
            animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        onboardingViewController = nil
        updateWindowState(
            presets: model.store.presets,
            selectedID: selection.selectedID
        )
        window?.makeFirstResponder(nil)
    }

    private func configureToolbar(for window: NSWindow) {
        let toolbar = NSToolbar(identifier: Self.toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        window.toolbar = toolbar
    }

    private func replaceToolbarItems(
        with identifiers: [NSToolbarItem.Identifier]
    ) {
        guard let toolbar = window?.toolbar else { return }

        while !toolbar.items.isEmpty {
            toolbar.removeItem(at: toolbar.items.count - 1)
        }
        for (index, identifier) in identifiers.enumerated() {
            toolbar.insertItem(withItemIdentifier: identifier, at: index)
        }
        toolbar.isVisible = true
    }

    func installPresetMenuIfNeeded() {
        installPresetMenu()
    }

    private func installPresetMenu() {
        guard let mainMenu = NSApp.mainMenu,
              !mainMenu.items.contains(where: {
                  $0.identifier == Self.presetMenuIdentifier
              }) else { return }

        let menuTitle = String(localized: "menu.preset")
        let submenu = NSMenu(title: menuTitle)
        submenu.addItem(
            makeMenuItem(
                title: String(localized: "action.addPreset"),
                action: #selector(addPreset(_:)),
                keyEquivalent: "n"
            )
        )
        submenu.addItem(.separator())
        submenu.addItem(
            makeMenuItem(
                title: String(localized: "action.duplicatePreset"),
                action: #selector(duplicateSelectedPreset(_:)),
                keyEquivalent: "d"
            )
        )
        submenu.addItem(
            makeMenuItem(
                title: String(localized: "action.deletePreset"),
                action: #selector(deleteSelectedPreset(_:)),
                keyEquivalent: "\u{8}"
            )
        )

        let menuItem = NSMenuItem(title: menuTitle, action: nil, keyEquivalent: "")
        menuItem.identifier = Self.presetMenuIdentifier
        menuItem.submenu = submenu

        let insertionIndex = mainMenu.items.firstIndex {
            $0.submenu === NSApp.windowsMenu
        } ?? max(0, mainMenu.numberOfItems - 1)
        mainMenu.insertItem(menuItem, at: insertionIndex)
    }

    private func makeMenuItem(
        title: String,
        action: Selector,
        keyEquivalent: String
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = .command
        return item
    }

    private func observeModel() {
        Publishers.CombineLatest(model.store.$presets, selection.$selectedID)
            .sink { [weak self] presets, selectedID in
                self?.updateWindowState(presets: presets, selectedID: selectedID)
            }
            .store(in: &observations)
    }

    private func updateWindowState(
        presets: [Preset],
        selectedID: UUID?
    ) {
        guard !isShowingOnboarding else {
            window?.title = "Arson"
            window?.toolbar?.validateVisibleItems()
            return
        }

        if let selectedID,
           let preset = presets.first(where: { $0.id == selectedID }) {
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
        relinquishToolbarFocusIfNeeded(sender)
    }

    private func relinquishToolbarFocusIfNeeded(_ sender: Any?) {
        guard sender is NSToolbarItem || sender is NSButton else { return }
        window?.makeFirstResponder(nil)
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

@MainActor
private final class MainContentContainerViewController: NSViewController {
    private var displayedViewController: NSViewController?

    override func loadView() {
        view = NSView()
    }

    func setContent(_ viewController: NSViewController, animated: Bool) {
        guard displayedViewController !== viewController else { return }

        if let displayedViewController {
            displayedViewController.view.removeFromSuperview()
            displayedViewController.removeFromParent()
        }

        addChild(viewController)
        let contentView = viewController.view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.alphaValue = animated ? 0 : 1
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        displayedViewController = viewController

        guard animated else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            contentView.animator().alphaValue = 1
        }
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
        Self.defaultToolbarItemIdentifiers
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.defaultToolbarItemIdentifiers
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
            guard !isShowingOnboarding else { return false }
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
        case #selector(addPreset(_:)):
            return MainActor.assumeIsolated { !isShowingOnboarding }
        case #selector(duplicateSelectedPreset(_:)), #selector(deleteSelectedPreset(_:)):
            return MainActor.assumeIsolated {
                !isShowingOnboarding && selection.selectedID != nil
            }
        default:
            return true
        }
    }
}
