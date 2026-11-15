import XCTest

@MainActor
final class DiaryFlowTests: XCTestCase {
    func testPaperPagesProfilesSelectedDateWeeklyScheduleAndPersistence() {
        let app = XCUIApplication()
        app.launchEnvironment["FAMILY_DIARY_TEST_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        for title in ["Сегодня","Календарь","Дети","Дом","Покупки"] {
            XCTAssertTrue(app.buttons["tab.\(title)"].waitForExistence(timeout: 10))
            app.buttons["tab.\(title)"].tap()
            XCTAssertTrue(app.staticTexts["page.title"].label == title)
        }
        app.buttons["tab.Дети"].tap()
        app.buttons["primary.Дети"].tap()
        XCTAssertTrue(app.navigationBars["Новый ребёнок"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["entry.title"].exists)
        app.textFields["member.name"].tap(); app.textFields["member.name"].typeText("Милана")
        app.textFields["Класс · если ребёнок учится"].tap(); app.textFields["Класс · если ребёнок учится"].typeText("6 класс")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts["Милана"].firstMatch.waitForExistence(timeout: 5))

        app.buttons["tab.Покупки"].tap(); app.buttons["primary.Покупки"].tap()
        XCTAssertTrue(app.navigationBars["Новая покупка"].exists)
        XCTAssertFalse(app.buttons["entry.repeat"].exists)
        app.textFields["entry.title"].tap(); app.textFields["entry.title"].typeText("Молоко")
        app.textFields["Количество, например 2 л"].tap(); app.textFields["Количество, например 2 л"].typeText("2 л")
        app.buttons["Сохранить"].tap()
        XCTAssertTrue(app.staticTexts["Молоко"].waitForExistence(timeout: 5))

        app.buttons["tab.Календарь"].tap()
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let components = calendar.dateComponents([.year,.month,.day], from: tomorrow)
        let key = String(format: "%04d-%02d-%02d", components.year!,components.month!,components.day!)
        app.buttons["calendar.date.\(key)"].tap()
        app.buttons["calendar.addReminder"].tap()
        app.textFields["entry.title"].tap(); app.textFields["entry.title"].typeText("Приём у педиатра")
        app.buttons["Сохранить"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Разрешить"].waitForExistence(timeout: 5) { springboard.buttons["Разрешить"].tap() }
        else if springboard.buttons["Allow"].exists { springboard.buttons["Allow"].tap() }
        if app.alerts["Запись сохранена"].exists { app.alerts.buttons["Готово"].tap() }
        XCTAssertTrue(app.buttons["Приём у педиатра"].waitForExistence(timeout: 10))

        app.buttons["tab.Дом"].tap(); app.buttons["home.weekday.2"].tap(); app.buttons["primary.Дом"].tap()
        XCTAssertTrue(app.navigationBars["Недельный график"].waitForExistence(timeout: 5))
        app.textFields["entry.title"].tap(); app.textFields["entry.title"].typeText("Вынести мусор")
        app.buttons["entry.owner"].tap(); app.buttons["Милана"].firstMatch.tap()
        app.swipeUp()
        let chosen = [2,4,6]
        for day in 1...7 {
            let button = app.buttons["entry.weekday.\(day)"]
            XCTAssertTrue(button.exists)
            if button.isSelected != chosen.contains(day) { button.tap() }
        }
        app.buttons["Сохранить"].tap()
        app.buttons["home.weekday.2"].tap()
        XCTAssertTrue(app.staticTexts["Вынести мусор"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Пн, Ср, Пт"].exists)
        app.buttons["home.weekday.3"].tap()
        XCTAssertFalse(app.staticTexts["Вынести мусор"].exists)

        app.terminate(); app.launch()
        app.buttons["tab.Покупки"].tap()
        XCTAssertTrue(app.staticTexts["Молоко"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 л"].exists)
        app.buttons["tab.Дом"].tap(); app.buttons["home.weekday.2"].tap()
        XCTAssertTrue(app.staticTexts["Вынести мусор"].exists)
        app.buttons["tab.Календарь"].tap(); app.buttons["calendar.date.\(key)"].tap()
        XCTAssertTrue(app.buttons["Приём у педиатра"].exists)
        for title in ["Сегодня","Календарь","Дети","Дом","Покупки"] {
            app.buttons["tab.\(title)"].tap()
            let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = title; attachment.lifetime = .keepAlways; add(attachment)
        }
    }
}
