import XCTest

final class ScreenshotTests: XCTestCase {
    func testOnboardingScreenshot() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory"]
        app.launch()

        let nameField = app.textFields["onboarding-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        attachScreenshot("onboarding", app: app)
        nameField.tap()
        nameField.typeText("Mia")
        app.buttons["onboarding-next"].tap()
        app.buttons["onboarding-next"].tap()
        let startAdventure = app.buttons["start-adventure"]
        XCTAssertTrue(startAdventure.waitForExistence(timeout: 10))
        attachScreenshot("onboarding-buddy", app: app)
    }

    func testMainLearningAndParentScreenshots() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory", "-UITestProfile", "Mia"]
        app.launch()

        let map = app.buttons["world-numberKingdom"]
        XCTAssertTrue(map.waitForExistence(timeout: 15))
        attachScreenshot("world-map", app: app)
        map.tap()

        let firstTopic = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "topic-")
        ).firstMatch
        XCTAssertTrue(firstTopic.waitForExistence(timeout: 10))
        attachScreenshot("topic-path", app: app)
        firstTopic.tap()

        let hint = app.buttons["hint-button"]
        XCTAssertTrue(hint.waitForExistence(timeout: 10))
        attachScreenshot("puzzle", app: app)
        hint.tap()
        XCTAssertTrue(app.staticTexts["hint-message"].waitForExistence(timeout: 5))
        attachScreenshot("puzzle-hint", app: app)
        app.buttons["plank-correct"].tap()
        app.buttons["check-answer"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["reward-panel"].waitForExistence(timeout: 10))
        attachScreenshot("puzzle-reward", app: app)
        app.buttons["next-puzzle"].tap()
        app.buttons["back-from-puzzle"].tap()
        app.buttons["back-to-map"].tap()

        app.buttons["parent-zone"].tap()
        let prompt = app.descendants(matching: .any)["parent-gate-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        let answer = try XCTUnwrap(prompt.value as? String)
        attachScreenshot("parent-gate", app: app)
        for digit in answer {
            app.buttons["gate-digit-\(digit)"].tap()
        }
        app.buttons["gate-submit"].tap()
        XCTAssertTrue(app.buttons["parent-dashboard-done"].waitForExistence(timeout: 10))
        attachScreenshot("parent-dashboard", app: app)
        app.buttons["parent-dashboard-done"].tap()

        let lockedWorld = app.buttons["world-logicLagoon"]
        XCTAssertTrue(lockedWorld.waitForExistence(timeout: 10))
        lockedWorld.tap()
        XCTAssertTrue(app.buttons["close-coming-soon"].waitForExistence(timeout: 5))
        attachScreenshot("locked-world", app: app)
    }

    func testPlankDragCompletesPuzzle() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-UITestInMemory", "-UITestProfile", "Mia"]
        app.launch()

        let map = app.buttons["world-numberKingdom"]
        XCTAssertTrue(map.waitForExistence(timeout: 15))
        map.tap()

        let firstTopic = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "topic-")
        ).firstMatch
        XCTAssertTrue(firstTopic.waitForExistence(timeout: 10))
        firstTopic.tap()

        let plank = app.buttons["plank-correct"]
        let dropArea = app.descendants(matching: .any)["bridge-drop-target"]
        XCTAssertTrue(plank.waitForExistence(timeout: 10))
        XCTAssertTrue(dropArea.waitForExistence(timeout: 10))
        plank.press(forDuration: 0.05, thenDragTo: dropArea)
        app.buttons["check-answer"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["reward-panel"].waitForExistence(timeout: 10))
    }

    private func attachScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
