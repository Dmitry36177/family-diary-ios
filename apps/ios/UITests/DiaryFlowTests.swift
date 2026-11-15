import XCTest

@MainActor
final class DiaryFlowTests: XCTestCase {
    func testFiveScreensAndOfflinePersistence() {
        let app = XCUIApplication()
        app.launchEnvironment["FAMILY_DIARY_TEST_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        for title in ["Сегодня", "Календарь", "Дети", "Дом", "Покупки"] {
            XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 10))
            app.tabBars.buttons[title].tap()
            XCTAssertTrue(app.navigationBars[title].exists)
        }

        app.buttons["Настройки"].firstMatch.tap()
        app.buttons["Добавить профиль"].tap()
        app.textFields["Имя"].tap()
        app.textFields["Имя"].typeText("Милана")
        app.buttons["Сохранить"].tap()
        app.buttons["Готово"].tap()
        app.tabBars.buttons["Дети"].tap()
        XCTAssertTrue(app.staticTexts["Милана"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Покупки"].tap()
        app.buttons["Добавить"].firstMatch.tap()
        app.textFields["Название"].tap()
        app.textFields["Название"].typeText("Молоко")
        app.textFields["Количество, например 2 л"].tap()
        app.textFields["Количество, например 2 л"].typeText("2 л")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts["Молоко"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["Покупки"].tap()
        XCTAssertTrue(app.staticTexts["Молоко"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 л"].exists)

        for title in ["Сегодня", "Календарь", "Дети", "Дом", "Покупки"] {
            app.tabBars.buttons[title].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = title
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
