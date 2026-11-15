import SwiftUI

struct DiaryEntryEditor: View {
    @Environment(DiaryStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.dismiss) private var dismiss
    @State var entry: DiaryEntry
    @State private var hasDate = false
    @State private var reminders = false
    @State private var busy = false
    @State private var confirmDelete = false
    @State private var error: String?

    private var existing: Bool { store.diaryEntries.contains { $0.id == entry.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Запись") {
                    TextField("Название", text: $entry.title)
                    Picker("Тип", selection: $entry.kind) {
                        ForEach(DiaryKind.allCases, id: \.self) { kind in Text(kind.title).tag(kind) }
                    }
                    Picker("Кому", selection: $entry.personId) {
                        Text("Без профиля").tag(String?.none)
                        ForEach(store.members) { member in Text(member.name).tag(Optional(member.id)) }
                    }
                    TextField("Заметка", text: $entry.note, axis: .vertical).lineLimit(3...8)
                }
                if entry.kind == .shopping {
                    Section("Покупка") {
                        TextField("Количество, например 2 л", text: $entry.quantity)
                        Picker("Раздел", selection: $entry.category) {
                            ForEach(DiaryEntry.shoppingCategories, id: \.self) { Text($0) }
                        }
                    }
                } else {
                    Section("Дата и напоминание") {
                        Toggle("Указать дату", isOn: $hasDate)
                        if hasDate {
                            DatePicker("Когда", selection: Binding(get: { entry.dueAt ?? Date() }, set: { entry.dueAt = $0 }))
                            Picker("Повтор", selection: $entry.repeatRule) {
                                ForEach(DiaryRepeat.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            Toggle("Напомнить", isOn: $reminders)
                            if reminders {
                                Picker("Время", selection: Binding(get: { entry.reminderMinutes ?? 15 }, set: { entry.reminderMinutes = $0 })) {
                                    Text("В момент события").tag(0)
                                    Text("За 15 минут").tag(15)
                                    Text("За час").tag(60)
                                    Text("За день").tag(1440)
                                }
                            }
                        }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
                if existing {
                    Section { Button("Удалить запись", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(existing ? "Изменить запись" : "Новая запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Сохраняем…" : "Сохранить") { Task { await save() } }
                        .disabled(busy || entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Удалить запись для всей семьи?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    Task {
                        busy = true
                        if await store.deleteDiaryEntry(entry.id) { dismiss() }
                        busy = false
                    }
                }
            }
            .onAppear { hasDate = entry.dueAt != nil; reminders = entry.reminderMinutes != nil }
        }
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .interactiveDismissDisabled(busy)
    }

    private func save() async {
        busy = true; error = nil
        defer { busy = false }
        if !hasDate || entry.kind == .shopping {
            entry.dueAt = nil; entry.repeatRule = .never; entry.reminderMinutes = nil
        } else {
            if entry.dueAt == nil { entry.dueAt = Date() }
            entry.reminderMinutes = reminders ? (entry.reminderMinutes ?? 15) : nil
        }
        if reminders, hasDate {
            notifications.enabled = true
            if !(await notifications.requestAuthorization()) {
                error = "Уведомления запрещены в iOS. Запись сохранится; разрешить уведомления можно в настройках iPhone."
            }
        }
        guard await store.saveDiaryEntry(entry) else { error = store.diaryError; store.diaryError = nil; return }
        if error == nil { dismiss() }
    }
}
