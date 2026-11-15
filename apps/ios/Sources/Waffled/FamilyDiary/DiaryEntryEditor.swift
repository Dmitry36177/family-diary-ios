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
    @State private var permissionNotice = false
    @State private var addPerson = false
    private var existing: Bool { store.diaryEntries.contains { $0.id == entry.id } }
    private var shopping: Bool { entry.kind == .shopping }
    private var weekly: Bool { entry.repeatRule == .weekly }
    private var heading: String {
        if shopping { return existing ? "Изменить покупку" : "Новая покупка" }
        if entry.kind == .home { return weekly ? "Недельный график" : "Домашнее дело" }
        if entry.kind == .event { return "Новое напоминание" }
        return entry.kind.title
    }
    private var date: Binding<Date> { Binding(get: { entry.dueAt ?? Date() }, set: { entry.dueAt = $0 }) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(shopping ? "Название товара" : entry.kind == .home ? "Домашнее дело" : "О чём напомнить", text: $entry.title)
                        .accessibilityIdentifier("entry.title")
                    if shopping {
                        TextField("Количество, например 2 л", text: $entry.quantity)
                        Picker("Раздел", selection: $entry.category) { ForEach(DiaryEntry.shoppingCategories, id: \.self) { Text($0) } }
                    } else {
                        Picker(entry.kind.isChildEntry ? "Ребёнок" : "Ответственный", selection: $entry.personId) {
                            Text(weekly && entry.kind == .home ? "Выберите профиль" : "Без профиля").tag(String?.none)
                            ForEach(store.members.filter { !entry.kind.isChildEntry || $0.isChild }) { Text($0.name).tag(Optional($0.id)) }
                        }.accessibilityIdentifier("entry.owner")
                        if !entry.kind.isChildEntry { Button("Добавить профиль ответственного", systemImage: "person.badge.plus") { addPerson = true } }
                        TextField("Заметка", text: $entry.note, axis: .vertical).lineLimit(2...6)
                    }
                }.listRowBackground(Paper.page.opacity(0.9))
                if !shopping {
                    Section {
                        if entry.kind != .event && !(entry.kind == .home && weekly) { Toggle("Указать дату", isOn: $hasDate) }
                        if hasDate || entry.kind == .event || (entry.kind == .home && weekly) {
                            DatePicker(weekly ? "Начало графика" : "Дата", selection: date, displayedComponents: .date).accessibilityIdentifier("entry.date")
                            DatePicker("Время", selection: date, displayedComponents: .hourAndMinute)
                            Picker("Повтор", selection: $entry.repeatRule) { ForEach(DiaryRepeat.allCases, id: \.self) { Text($0.title).tag($0) } }
                                .accessibilityIdentifier("entry.repeat")
                            if weekly { weekdayPicker }
                            Toggle("Напомнить", isOn: $reminders)
                            if reminders {
                                Picker("Уведомление", selection: Binding(get: { entry.reminderMinutes ?? 15 }, set: { entry.reminderMinutes = $0 })) {
                                    Text("В момент события").tag(0); Text("За 15 минут").tag(15); Text("За час").tag(60); Text("За день").tag(1440)
                                }
                            }
                        }
                    } header: { Text(weekly ? "Повторять каждую неделю" : "Дата и напоминание").font(.system(.subheadline, design: .serif)) }
                    footer: { if weekly { Text("Дни и время повторятся каждую неделю. Ответственный назначается этому делу.") } }
                    .listRowBackground(Paper.page.opacity(0.9))
                }
                if let error { Section { Text(error).foregroundStyle(Paper.rose) }.listRowBackground(Paper.page) }
                if existing { Section { Button(entry.repeatRule == .never ? "Удалить запись" : "Удалить весь график", role: .destructive) { confirmDelete = true } }.listRowBackground(Paper.page) }
            }
            .scrollContentBackground(.hidden).background(PaperBackground())
            .navigationTitle(heading).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Paper.page, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "Сохраняем…" : "Сохранить") { Task { await save() } }
                        .disabled(busy || entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog(entry.repeatRule == .never ? "Удалить запись?" : "Удалить график и все будущие повторения?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { Task { busy = true; if await store.deleteDiaryEntry(entry.id) { dismiss() }; busy = false } }
            }
            .alert("Запись сохранена", isPresented: $permissionNotice) { Button("Готово") { dismiss() } } message: {
                Text("Уведомления запрещены в iOS. Разрешите их в настройках iPhone, чтобы получать напоминания.")
            }
            .sheet(isPresented: $addPerson) { DiaryMemberEditor(member: DiaryMember(name: "", isChild: false)) }
            .onAppear {
                hasDate = entry.dueAt != nil; reminders = entry.reminderMinutes != nil
                if weekly && entry.weekdays == nil, let due = entry.dueAt { entry.weekdays = [DiaryDates.calendar.component(.weekday, from: due)] }
            }
            .onChange(of: entry.repeatRule) { _, value in
                if value == .weekly && (entry.weekdays ?? []).isEmpty { entry.weekdays = [DiaryDates.calendar.component(.weekday, from: entry.dueAt ?? Date())] }
            }
        }.environment(\.locale, Locale(identifier: "ru_RU")).tint(Paper.sage).interactiveDismissDisabled(busy)
    }
    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Дни недели").font(.subheadline)
            HStack(spacing: 3) {
                ForEach(0..<7) { index in
                    let day = DiaryDates.weekdays[index]
                    let selected = (entry.weekdays ?? []).contains(day)
                    Button {
                        var values = entry.weekdays ?? []
                        if selected { values.removeAll { $0 == day } } else { values.append(day) }
                        entry.weekdays = values
                    } label: {
                        Text(DiaryDates.labels[index]).font(.system(size: 13, design: .serif))
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .foregroundStyle(selected ? Paper.page : Paper.gold)
                            .background(selected ? Paper.sage : Paper.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                    }.buttonStyle(.plain).accessibilityIdentifier("entry.weekday.\(day)").accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }.padding(.vertical, 5)
    }
    private func save() async {
        busy = true; error = nil
        defer { busy = false }
        if shopping { entry.dueAt = nil; entry.repeatRule = .never; entry.reminderMinutes = nil; entry.personId = nil }
        else {
            if !hasDate && entry.kind != .event && !(entry.kind == .home && weekly) { entry.dueAt = nil; entry.repeatRule = .never; entry.reminderMinutes = nil }
            else { if entry.dueAt == nil { entry.dueAt = Date() }; entry.reminderMinutes = reminders ? (entry.reminderMinutes ?? 15) : nil }
            if weekly {
                guard !(entry.weekdays ?? []).isEmpty else { error = "Выберите хотя бы один день недели."; return }
                if entry.kind == .home && entry.personId == nil { error = "Выберите ответственного за это дело."; return }
            }
        }
        guard await store.saveDiaryEntry(entry) else { error = store.diaryError; store.diaryError = nil; return }
        if reminders && !shopping { notifications.enabled = true; if !(await notifications.requestAuthorization()) { permissionNotice = true; return } }
        dismiss()
    }
}
