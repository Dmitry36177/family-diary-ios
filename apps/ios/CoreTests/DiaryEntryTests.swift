import XCTest
#if canImport(FamilyDiaryCore)
@testable import FamilyDiaryCore
#else
@testable import Waffled
#endif

final class DiaryEntryTests: XCTestCase {
    let tz = TimeZone(identifier: "Europe/Moscow")!
    func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testRepeatingReminderKeepsHouseholdWallClockAcrossDST() {
        let zone = TimeZone(identifier: "Europe/Berlin")!
        let entry = DiaryEntry(title: "Школа", kind: .school,
                               dueAt: date("2026-03-28T08:00:00Z"), repeatRule: .daily, reminderMinutes: 15)
        let next = entry.nextOccurrence(onOrAfter: date("2026-03-29T00:00:00Z"), tz: zone)
        XCTAssertEqual(next, date("2026-03-29T07:00:00Z"))
    }

    func testReminderLeadAndCompletedItems() {
        var entry = DiaryEntry(title: "Педиатр", kind: .appointment,
                               dueAt: date("2026-11-16T12:00:00Z"), reminderMinutes: 60)
        XCTAssertEqual(entry.nextReminder(after: date("2026-11-15T00:00:00Z"), tz: tz), date("2026-11-16T11:00:00Z"))
        entry.completed = true
        XCTAssertNil(entry.nextReminder(after: date("2026-11-15T00:00:00Z"), tz: tz))
    }

    func testPastOneShotDoesNotRescheduleAndNoReminderMeansNone() {
        var entry = DiaryEntry(title: "Дело", kind: .home, dueAt: date("2026-11-01T12:00:00Z"), reminderMinutes: 0)
        XCTAssertNil(entry.nextReminder(after: date("2026-11-15T00:00:00Z"), tz: tz))
        entry.reminderMinutes = nil
        XCTAssertNil(entry.nextReminder(after: date("2026-10-15T00:00:00Z"), tz: tz))
    }

    func testWeeklyOccurrenceAppearsOnlyOnCorrectDay() {
        let entry = DiaryEntry(title: "Уборка", kind: .home,
                               dueAt: date("2026-11-16T09:00:00Z"), repeatRule: .weekly)
        XCTAssertTrue(entry.occurs(on: date("2026-11-23T15:00:00Z"), tz: tz))
        XCTAssertFalse(entry.occurs(on: date("2026-11-24T15:00:00Z"), tz: tz))
        XCTAssertFalse(entry.occurs(on: date("2026-11-09T15:00:00Z"), tz: tz))
    }

    func testMonthlyDoesNotDriftAfterShortMonth() {
        let entry = DiaryEntry(title: "Проверка", kind: .home,
                               dueAt: date("2026-01-31T09:00:00Z"), repeatRule: .monthly)
        XCTAssertEqual(entry.nextOccurrence(onOrAfter: date("2026-03-01T00:00:00Z"), tz: tz), date("2026-03-31T09:00:00Z"))
    }

    func testOfflineSnapshotRoundTrip() throws {
        let entry = DiaryEntry(title: "Молоко", kind: .shopping, quantity: "2 л", category: "Продукты")
        let encoded = try JSONEncoder().encode(entry)
        XCTAssertEqual(try JSONDecoder().decode(DiaryEntry.self, from: encoded), entry)
    }

    func testReminderLimitKeepsEarliestAndStableIdentifiers() {
        let now = date("2026-11-15T00:00:00Z")
        let entries = (1...70).map { offset in
            DiaryEntry(title: "Дело \(offset)", kind: .home,
                       dueAt: now.addingTimeInterval(Double(offset) * 60), reminderMinutes: 0)
        }
        let plan = DiaryReminderPlan.make(entries: entries, now: now, tz: tz)
        XCTAssertEqual(plan.reminders.count, 58)
        XCTAssertEqual(plan.beyondLimit, 12)
        XCTAssertEqual(plan.reminders.first?.title, "Дело 1")
        XCTAssertEqual(plan.reminders.last?.title, "Дело 58")
        XCTAssertEqual(Set(plan.reminders.map(\.identifier)).count, 58)
        XCTAssertEqual(plan.reminders, DiaryReminderPlan.make(entries: entries, now: now, tz: tz).reminders)
    }

    func testRepeatPlanAdvancesAndCompletedItemHasNoNotifications() {
        let now = date("2026-11-15T00:00:00Z")
        var entry = DiaryEntry(title: "Уборка", kind: .home, dueAt: date("2026-11-16T09:00:00Z"),
                               repeatRule: .daily, reminderMinutes: 15)
        let plan = DiaryReminderPlan.make(entries: [entry], now: now, tz: tz, limit: 3)
        XCTAssertEqual(plan.reminders.map(\.fireAt), [date("2026-11-16T08:45:00Z"),date("2026-11-17T08:45:00Z"),date("2026-11-18T08:45:00Z")])
        entry.completed = true
        XCTAssertTrue(DiaryReminderPlan.make(entries: [entry], now: now, tz: tz).reminders.isEmpty)
    }
}
