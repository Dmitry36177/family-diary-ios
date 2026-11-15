import Foundation

enum DiaryKind: String, Codable, CaseIterable, Sendable {
    case event, home, school, homework, vaccination, appointment, growth, illness, development, shopping

    var title: String {
        switch self {
        case .event: "Событие"
        case .home: "Домашнее дело"
        case .school: "Расписание"
        case .homework: "Домашнее задание"
        case .vaccination: "Прививка"
        case .appointment: "Приём у врача"
        case .growth: "Рост и вес"
        case .illness: "История здоровья"
        case .development: "Развитие"
        case .shopping: "Покупка"
        }
    }

    var icon: String {
        switch self {
        case .event: "calendar"
        case .home: "house"
        case .school, .homework: "graduationcap"
        case .vaccination: "syringe"
        case .appointment, .illness: "heart"
        case .growth: "ruler"
        case .development: "figure.child"
        case .shopping: "basket"
        }
    }

    var isChildEntry: Bool {
        [.school, .homework, .vaccination, .appointment, .growth, .illness, .development].contains(self)
    }
}

enum DiaryRepeat: String, Codable, CaseIterable, Sendable {
    case never, daily, weekly, monthly
    var title: String {
        switch self {
        case .never: "Не повторять"
        case .daily: "Каждый день"
        case .weekly: "Каждую неделю"
        case .monthly: "Каждый месяц"
        }
    }
}

struct DiaryEntry: Identifiable, Codable, Equatable, Sendable {
    var id = UUID().uuidString.lowercased()
    var title: String
    var kind: DiaryKind
    var note = ""
    var personId: String?
    var dueAt: Date?
    var repeatRule: DiaryRepeat = .never
    var reminderMinutes: Int?
    var quantity = ""
    var category = "Продукты"
    var completed = false

    static let shoppingCategories = ["Продукты", "Детям", "Бытовая химия", "Для дома"]
    static let reminderOptions = [0, 15, 60, 1440]

    func nextOccurrence(onOrAfter threshold: Date, tz: TimeZone) -> Date? {
        guard let dueAt else { return nil }
        if dueAt >= threshold { return dueAt }
        guard repeatRule != .never else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let component: Calendar.Component = repeatRule == .daily ? .day : repeatRule == .weekly ? .weekOfYear : .month
        let elapsed = calendar.dateComponents([component], from: dueAt, to: threshold).value(for: component) ?? 0
        // Always add from the original date so a short February cannot shift March's day.
        for offset in max(1, elapsed - 1)...max(3, elapsed + 2) {
            if let candidate = calendar.date(byAdding: component, value: offset, to: dueAt), candidate >= threshold {
                return candidate
            }
        }
        return nil
    }

    func nextReminder(after now: Date, tz: TimeZone) -> Date? {
        guard !completed, let reminderMinutes else { return nil }
        let lead = TimeInterval(reminderMinutes * 60)
        guard let next = nextOccurrence(onOrAfter: now.addingTimeInterval(lead + 1), tz: tz) else { return nil }
        return next.addingTimeInterval(-lead)
    }

    func occurs(on day: Date, tz: TimeZone) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start),
              let next = nextOccurrence(onOrAfter: start, tz: tz) else { return false }
        return next < end
    }
}
