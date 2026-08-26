import AppKit
import XCTest

final class ArsonUITests: XCTestCase {
    @MainActor
    func testMenuBarIconUsesNativePopUpButton() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-completedOnboardingVersion", "2",
            "-menuBarIconStyle", "windows",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.launch()

        app.typeKey(",", modifierFlags: .command)

        let iconPicker = app.popUpButtons["menuBarIconPicker"]
        XCTAssertTrue(iconPicker.waitForExistence(timeout: 5))
        XCTAssertEqual(iconPicker.value as? String, "Windows")
        let initialWidth = iconPicker.frame.width

        iconPicker.click()
        let flameItem = app.menuItems["Flame"]
        XCTAssertTrue(flameItem.waitForExistence(timeout: 2))
        flameItem.click()
        XCTAssertEqual(iconPicker.value as? String, "Flame")
        XCTAssertEqual(iconPicker.frame.width, initialWidth, accuracy: 0.5)
    }

    @MainActor
    func testValidationMessageAppearsBeforeItsControl() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-completedOnboardingVersion", "2",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.launch()

        let recorder = app.buttons["Record global shortcut"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5))
        recorder.click()
        recorder.typeKey("1", modifierFlags: [])

        let validationMessage = app.staticTexts["Use at least Command, Option, or Control."]
        XCTAssertTrue(validationMessage.waitForExistence(timeout: 3))
        XCTAssertLessThan(validationMessage.frame.maxX, recorder.frame.minX)
        XCTAssertEqual(validationMessage.frame.midY, recorder.frame.midY, accuracy: 2)
    }

    @MainActor
    func testGeometryValuesUseEditableNativeSteppers() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-completedOnboardingVersion", "2",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.launch()

        let widthStepper = app.steppers["Width"]
        let widthField = app.textFields["Width"]
        XCTAssertTrue(widthStepper.waitForExistence(timeout: 5))
        XCTAssertTrue(widthField.exists)
        XCTAssertEqual(widthField.value as? String, "80")

        widthField.click()
        widthField.typeKey("a", modifierFlags: .command)
        widthField.typeText("81")
        widthField.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(widthField.value as? String, "81")

        XCTAssertTrue(app.steppers["Height"].exists)
        XCTAssertTrue(app.steppers["X offset"].exists)
        XCTAssertTrue(app.steppers["Y offset"].exists)
    }

    @MainActor
    func testSidebarAccessoryCanCollapseAndReopen() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-completedOnboardingVersion", "2",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.launch()

        let addButton = app.buttons["Add Preset"]
        let accessoryToggle = app.buttons.matching(
            NSPredicate(
                format: "label == %@ OR label == %@",
                "Show or Hide Sidebar",
                "Sidebar"
            )
        ).firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(accessoryToggle.isHittable)

        assertSidebarWidth(250, in: app)

        accessoryToggle.click()

        let toolbarToggle = app.buttons["Sidebar"]
        XCTAssertTrue(toolbarToggle.waitForExistence(timeout: 3))
        XCTAssertTrue(toolbarToggle.isHittable)
        toolbarToggle.click()

        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addButton.isHittable)
    }

    @MainActor
    func testClosingMainWindowHandsFocusToCurrentDesktopAndReopens() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-completedOnboardingVersion", "2",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.launch()

        let mainWindow = app.windows["ArsonMainWindow"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        let runningApplication = try XCTUnwrap(
            NSRunningApplication.runningApplications(
                withBundleIdentifier: "de.lukasharzbecker.arson"
            ).max { first, second in
                (first.launchDate ?? .distantPast) < (second.launchDate ?? .distantPast)
            }
        )
        let bundleURL = try XCTUnwrap(runningApplication.bundleURL)
        let processIdentifier = runningApplication.processIdentifier

        let closeButton = mainWindow.buttons[XCUIIdentifierCloseWindow]
        XCTAssertTrue(closeButton.isHittable)
        closeButton.click()

        XCTAssertTrue(mainWindow.waitForNonExistence(timeout: 3))
        let finderIsFrontmost = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                    == "com.apple.finder"
            },
            object: nil
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [finderIsFrontmost], timeout: 3),
            .completed
        )
        XCTAssertEqual(app.state, .runningBackground)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        configuration.allowsRunningApplicationSubstitution = false
        configuration.appleEvent = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: NSAppleEventDescriptor(
                processIdentifier: processIdentifier
            ),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        let reopenExpectation = expectation(
            description: "Launch Services reopens the existing Arson process"
        )
        NSWorkspace.shared.openApplication(
            at: bundleURL,
            configuration: configuration,
            completionHandler: { reopenedApplication, error in
                XCTAssertNil(error)
                XCTAssertEqual(
                    reopenedApplication?.processIdentifier,
                    processIdentifier
                )
                reopenExpectation.fulfill()
            }
        )
        wait(for: [reopenExpectation], timeout: 5)
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        XCTAssertFalse(
            try XCTUnwrap(
                NSRunningApplication(processIdentifier: processIdentifier)
            ).isTerminated
        )
    }

    @MainActor
    func testPresetCommandsAppearInMenuBar() {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-completedOnboardingVersion", "2",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.launch()

        XCTAssertTrue(app.buttons["Add Preset"].waitForExistence(timeout: 5))
        let presetMenu = app.menuBars.menuBarItems["Preset"]
        XCTAssertTrue(presetMenu.exists)
        presetMenu.click()
        XCTAssertTrue(app.menuItems["Add Preset"].exists)
        XCTAssertTrue(app.menuItems["Duplicate Preset"].exists)
        XCTAssertTrue(app.menuItems["Delete Preset"].exists)
    }

    @MainActor
    func testOnboardingAndPresetCreation() throws {
        continueAfterFailure = false

        let app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing-reset",
            "-ui-testing-permission-untrusted",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launchEnvironment["ARSON_TEST_STORAGE_DIRECTORY"] = NSTemporaryDirectory()
            + "ArsonUITests-\(UUID().uuidString)"
        app.terminate()
        app.launch()

        let mainWindow = app.windows["ArsonMainWindow"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 5))
        let initialFrame = mainWindow.frame

        XCTAssertTrue(app.staticTexts["Welcome to Arson"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Add Preset"].exists)
        app.buttons["Get Started"].click()

        XCTAssertTrue(app.staticTexts["Control Other App Windows"].waitForExistence(timeout: 3))
        assertEqual(initialFrame, mainWindow.frame)
        XCTAssertTrue(app.buttons["Continue"].exists)
        XCTAssertFalse(app.buttons["Request Access"].exists)
        XCTAssertFalse(app.staticTexts["System Settings › Privacy & Security › Device Control & Data Access"].exists)
        app.buttons["Continue"].click()

        XCTAssertTrue(app.staticTexts["Enable Arson in System Settings"].waitForExistence(timeout: 3))
        assertEqual(initialFrame, mainWindow.frame)
        XCTAssertTrue(app.buttons["Open System Settings"].exists)
        XCTAssertTrue(app.buttons["Continue Without Permission"].exists)
        XCTAssertFalse(app.staticTexts["System Settings › Privacy & Security › Device Control & Data Access"].exists)

        app.disclosureTriangles["Having Trouble?"].click()
        app.buttons["Continue Without Permission"].click()

        let addButton = app.buttons["Add Preset"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        assertSidebarWidth(250, in: app)
        XCTAssertTrue(app.buttons["Duplicate"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
        addButton.click()

        assertEqual(initialFrame, mainWindow.frame)
        XCTAssertGreaterThanOrEqual(mainWindow.frame.width, 720)
        XCTAssertGreaterThanOrEqual(mainWindow.frame.height, 480)
        XCTAssertTrue(app.cells["New Preset"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.textFields["presetNameField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["X offset"].exists)
        XCTAssertTrue(app.staticTexts["Y offset"].exists)
        try app.performAccessibilityAudit { issue in
            // SwiftUI exposes non-interactive layout containers and MenuBarExtra's
            // narrow support window as disabled elements that aren't user-facing.
            if issue.auditType == .sufficientElementDescription,
               let element = issue.element,
               (element.elementType == .menuBar || element.elementType == .touchBar ||
                (element.elementType == .group && !element.isEnabled) ||
                (element.elementType == .window && !element.isEnabled && element.frame.width <= 20)) {
                return true
            }
            // The system Picker is actionable, but macOS 27 beta reports its native
            // NSPopUpButton bridge as missing an AX action during automated audits.
            if issue.auditType == .action,
               issue.element?.elementType == .popUpButton {
                return true
            }
            // AppKit's native full-screen title-bar button exposes a disabled internal
            // group that macOS 26 reports as a parent/child mismatch.
            if issue.auditType == .parentChild,
               let element = issue.element,
               element.elementType == .group,
               !element.isEnabled {
                return true
            }
            // SwiftUI List rows use a system material that the macOS contrast sampler
            // misclassifies even with AppKit's semantic labelColor foreground.
            if issue.auditType == .contrast,
               let element = issue.element,
               element.elementType == .cell ||
               element.elementType == .outlineRow ||
               element.identifier == "presetRowName" {
                return true
            }
            // macOS 27 beta samples SwiftUI's native grouped Form material instead
            // of these semantic label colors, producing a false contrast failure.
            if issue.auditType == .contrast,
               let identifier = issue.element?.identifier,
               identifier == "configurationFieldLabel" ||
               identifier == "configurationHelpText" {
                return true
            }
            // macOS 27 beta samples the full native title-bar vibrancy region instead
            // of the title glyphs and can therefore report a false contrast failure.
            if issue.auditType == .contrast,
               let element = issue.element,
               element.elementType == .staticText,
               element.frame.minY <= app.windows.firstMatch.frame.minY + 1,
               element.frame.height <= 60 {
                return true
            }
            if let element = issue.element {
                print("Unhandled accessibility audit issue: \(issue.compactDescription)\n\(element.debugDescription)")
            }
            return false
        }
    }

    private func assertEqual(
        _ expected: CGRect,
        _ actual: CGRect,
        accuracy: CGFloat = 1
    ) {
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy)
    }

    @MainActor
    private func assertSidebarWidth(
        _ expected: Double,
        in app: XCUIApplication,
        accuracy: Double = 9
    ) {
        let divider = app.splitGroups.firstMatch.splitters.firstMatch
        XCTAssertTrue(divider.exists)
        let dividerPosition = (divider.value as? NSNumber)?.doubleValue
            ?? (divider.value as? String).flatMap { Double($0) }
        XCTAssertNotNil(dividerPosition)
        if let dividerPosition {
            // macOS 26 exposes the splitter position including the 8-point
            // full-size-content inset; macOS 27 exposes the sidebar width.
            XCTAssertEqual(dividerPosition, expected, accuracy: accuracy)
        }
    }
}
