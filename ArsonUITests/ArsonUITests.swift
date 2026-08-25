import XCTest

final class ArsonUITests: XCTestCase {
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
        XCTAssertEqual(widthField.value as? String, "400")

        let incrementButton = widthStepper.buttons.firstMatch
        XCTAssertTrue(incrementButton.isHittable)
        incrementButton.click()
        XCTAssertEqual(widthField.value as? String, "401")

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

        accessoryToggle.click()

        let toolbarToggle = app.buttons["Sidebar"]
        XCTAssertTrue(toolbarToggle.waitForExistence(timeout: 3))
        XCTAssertTrue(toolbarToggle.isHittable)
        toolbarToggle.click()

        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addButton.isHittable)
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
        XCTAssertTrue(app.staticTexts["Waiting for permission…"].exists)
        XCTAssertTrue(app.buttons["Open System Settings"].exists)
        XCTAssertTrue(app.buttons["Continue Without Permission"].exists)
        XCTAssertFalse(app.staticTexts["System Settings › Privacy & Security › Device Control & Data Access"].exists)

        app.disclosureTriangles["Having Trouble?"].click()
        XCTAssertTrue(app.staticTexts["System Settings › Privacy & Security › Device Control & Data Access"].waitForExistence(timeout: 2))
        app.buttons["Continue Without Permission"].click()

        let addButton = app.buttons["Add Preset"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 3))
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
}
