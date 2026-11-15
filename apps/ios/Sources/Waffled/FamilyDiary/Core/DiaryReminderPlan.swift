import Foundation

struct DiaryReminder: Equatable, Sendable {
    let entryId: String
    let title: String
    let fireAt: Date
    var identifier: String { "familyDiary.reminder.\(entryId).\(Int(fireAt.timeIntervalSince1970))" }
}

struct DiaryReminderPlan: Sendable {
    let reminders: [DiaryReminder]
    let beyondLimit: Int

    static func make(entries: [DiaryEntry], now: Date, tz: TimeZone, limit: Int = 58) -> DiaryReminderPlan {
        guard limit > 0 else { return .init(reminders: [], beyondLimit: entries.count) }
        var candidates: [DiaryReminder] = []
        for entry in entries {
            var cursor = now
            for _ in 0...limit {
                guard let fire = entry.nextReminder(after: cursor, tz: tz) else { break }
                candidates.append(.init(entryId: entry.id, title: entry.title, fireAt: fire))
                guard entry.repeatRule != .never else { break }
                cursor = fire.addingTimeInterval(1)
            }
        }
        candidates.sort { a, b in a.fireAt == b.fireAt ? a.entryId < b.entryId : a.fireAt < b.fireAt }
        return .init(reminders: Array(candidates.prefix(limit)), beyondLimit: max(0, candidates.count - limit))
    }
}
