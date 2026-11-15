import SwiftUI
import UserNotifications

struct DiarySettingsView: View {
    @Environment(DiaryStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @State private var member: DiaryMember?

    var body: some View {
        @Bindable var notifications = notifications
        NavigationStack {
            Form {
                Section("Напоминания") {
                    Toggle("Уведомления на этом iPhone", isOn: $notifications.enabled)
                        .onChange(of: notifications.enabled) { _, enabled in
                            if enabled { Task { await notifications.requestAuthorization() } }
                        }
                    if notifications.authorization == .denied {
                        Button("Разрешить в настройках iPhone") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    Text("Напоминания срабатывают без интернета. Время указывается в часовом поясе iPhone.")
                        .font(.caption).foregroundStyle(.secondary)
                    if notifications.droppedToCap > 0 {
                        Text("iOS ограничивает число запланированных уведомлений. Ближайшие добавлены; открывайте ежедневник, чтобы обновлять расписание повторений.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let error = notifications.schedulingError { Text(error).foregroundStyle(.red) }
                }
                Section("Профили") {
                    ForEach(store.members) { person in
                        Button { member = person } label: {
                            HStack {
                                Text(person.emoji); Text(person.name).foregroundStyle(.primary)
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Добавить профиль", systemImage: "person.badge.plus") { member = DiaryMember(name: "", isChild: true) }
                }
                Section("Данные") {
                    Text("Записи и профили хранятся на этом iPhone. Общего доступа и сервера нет.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LabeledContent("Записей", value: "\(store.diaryEntries.count)")
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .sheet(item: $member) { DiaryMemberEditor(member: $0) }
        }
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}

struct DiaryMemberEditor: View {
    @Environment(DiaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var member: DiaryMember
    @State private var confirmDelete = false
    private var existing: Bool { store.members.contains { $0.id == member.id } }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Имя", text: $member.name)
                Toggle("Ребёнок", isOn: $member.isChild)
                if existing { Button("Удалить профиль", role: .destructive) { confirmDelete = true } }
            }
            .navigationTitle(existing ? "Профиль" : "Новый профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { if store.saveMember(member) { dismiss() } }
                        .disabled(member.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Удалить профиль? Записи сохранятся без привязки к нему.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { if store.deleteMember(member.id) { dismiss() } }
            }
        }
    }
}
