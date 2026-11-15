import Testing
import Foundation
@testable import Waffled

@MainActor
struct PaperDiaryTests {
    let zone = TimeZone(identifier: "Europe/Moscow")!
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test func weeklyDaysAndResponsibleSurviveRelaunch() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DiaryStore(directory: folder)
        let adult = DiaryMember(name: "Дмитрий", isChild: false)
        #expect(store.saveMember(adult))
        var entry = DiaryEntry(title: "Вынести мусор", kind: .home, personId: adult.id,
                               dueAt: date("2026-11-16T17:00:00Z"), repeatRule: .weekly, reminderMinutes: 15)
        entry.weekdays = [2,4,6]
        #expect(await store.saveDiaryEntry(entry))
        let reopened = DiaryStore(directory: folder)
        #expect(reopened.diaryEntries.first?.weekdays == [2,4,6])
        #expect(reopened.diaryEntries.first?.personId == adult.id)
        #expect(entry.occurs(on: date("2026-11-18T12:00:00Z"), tz: zone))
        #expect(!entry.occurs(on: date("2026-11-19T12:00:00Z"), tz: zone))
        #expect(entry.occurs(on: date("2026-11-23T12:00:00Z"), tz: zone))
    }

    @Test func completingOneDayKeepsNextWeeklyReminder() {
        var entry = DiaryEntry(title: "Уборка", kind: .home, dueAt: date("2026-11-16T09:00:00Z"), repeatRule: .weekly, reminderMinutes: 0)
        entry.weekdays = [2,4]
        entry.toggleCompletion(on: date("2026-11-16T10:00:00Z"), tz: zone)
        #expect(entry.isCompleted(on: date("2026-11-16T10:00:00Z"), tz: zone))
        #expect(!entry.isCompleted(on: date("2026-11-18T10:00:00Z"), tz: zone))
        #expect(entry.nextReminder(after: date("2026-11-15T00:00:00Z"), tz: zone) == date("2026-11-18T09:00:00Z"))
    }

    @Test func oldDataRemainsReadable() throws {
        let old = """
        {"id":"legacy","title":"Молоко","kind":"shopping","note":"","repeatRule":"never","quantity":"2 л","category":"Продукты","completed":false}
        """
        let entry = try JSONDecoder().decode(DiaryEntry.self, from: Data(old.utf8))
        #expect(entry.weekdays == nil)
        #expect(entry.title == "Молоко")
        let member = try JSONDecoder().decode(DiaryMember.self, from: Data("{\"id\":\"child\",\"name\":\"Милана\",\"isChild\":true}".utf8))
        #expect(member.birthday == nil)
    }

    @Test func childBirthdayAndSchoolAreSaved() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = DiaryStore(directory: folder)
        var child = DiaryMember(name: "Милана", isChild: true)
        child.birthday = date("2015-05-14T09:00:00Z")
        child.schoolClass = "6 класс"
        #expect(store.saveMember(child))
        #expect(DiaryStore(directory: folder).members.first == child)
    }
}
