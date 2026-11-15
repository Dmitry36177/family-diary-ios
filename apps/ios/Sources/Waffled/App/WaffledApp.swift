import SwiftUI

@main
struct WaffledApp: App {
    @State private var store: DiaryStore = {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["FAMILY_DIARY_TEST_ID"], UUID(uuidString: id) != nil {
            return DiaryStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(id))
        }
        #endif
        return DiaryStore()
    }()
    @State private var notifications = NotificationManager()

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(store)
                .environment(notifications)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .preferredColorScheme(.light)
                .tint(DiaryStyle.blue)
        }
    }
}
