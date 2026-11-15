import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class NotificationManager {
    var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "familyDiary.notifications.enabled")
            Task { await apply() }
        }
    }
    var pendingEventId: String?
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var droppedToCap = 0
    private(set) var schedulingError: String?
    private let center = UNUserNotificationCenter.current()
    private let delegate = DiaryNotificationDelegate()
    private var entries: [DiaryEntry] = []
    private var tz: TimeZone = .current
    private var generation = 0
    private var tail: Task<Void, Never>?

    init() {
        enabled = UserDefaults.standard.object(forKey: "familyDiary.notifications.enabled") as? Bool ?? true
        delegate.manager = self
        center.delegate = delegate
    }

    func refreshAuthorization() async { authorization = await center.notificationSettings().authorizationStatus }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorization()
        await apply()
        return allowed
    }

    func reconcileDiary(entries: [DiaryEntry], tz: TimeZone) async {
        self.entries = entries; self.tz = tz
        await apply()
    }

    private func apply() async {
        generation += 1
        let mine = generation
        let predecessor = tail
        let task = Task { @MainActor in
            if let predecessor { await predecessor.value }
            guard mine == generation else { return }
            await installSchedule(generation: mine)
        }
        tail = task
        await task.value
        if mine == generation { tail = nil }
    }

    private func installSchedule(generation mine: Int) async {
        let pending = await center.pendingNotificationRequests()
        guard mine == generation else { return }
        let owned = pending.filter { $0.identifier.hasPrefix("familyDiary.reminder.") }
        let allowed = enabled && (authorization == .authorized || authorization == .provisional)
        let free = max(0, 64 - (pending.count - owned.count) - 2)
        let plan = DiaryReminderPlan.make(entries: allowed ? entries : [], now: Date(), tz: tz, limit: min(58, free))
        droppedToCap = allowed ? plan.beyondLimit : 0
        let desired = Set(plan.reminders.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: owned.map(\.identifier).filter { !desired.contains($0) })
        schedulingError = nil
        for reminder in plan.reminders {
            guard mine == generation else { return }
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "Напоминание из ежедневника"
            content.sound = .default
            content.threadIdentifier = "familyDiary"
            content.userInfo = ["entryId": reminder.entryId]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.fireAt.timeIntervalSinceNow), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
            } catch {
                schedulingError = "iOS не удалось добавить часть напоминаний. Откройте ежедневник ещё раз."
            }
        }
    }
}

private final class DiaryNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var manager: NotificationManager?
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let entryId = response.notification.request.content.userInfo["entryId"] as? String
        Task { @MainActor in manager?.pendingEventId = entryId; completionHandler() }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
