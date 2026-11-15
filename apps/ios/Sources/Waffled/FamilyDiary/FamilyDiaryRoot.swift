import SwiftUI
import UserNotifications

enum DiaryScreen: String, CaseIterable, Identifiable {
    case today = "Сегодня", calendar = "Календарь", children = "Дети", home = "Дом", shopping = "Покупки"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: "sun.max"
        case .calendar: "calendar"
        case .children: "person.2"
        case .home: "house"
        case .shopping: "basket"
        }
    }
    var newKind: DiaryKind {
        switch self {
        case .home: .home
        case .children: .homework
        case .shopping: .shopping
        default: .event
        }
    }
}

enum DiaryStyle {
    static let blue = Color(red: 0.23, green: 0.45, blue: 0.91)
    static let canvas = Color(red: 0.97, green: 0.98, blue: 1)
    static func tint(_ kind: DiaryKind) -> Color {
        switch kind {
        case .appointment, .illness: .pink
        case .vaccination, .growth: .teal
        case .school, .homework: .indigo
        case .shopping, .home: .green
        case .development: .orange
        case .event: blue
        }
    }
}

struct FamilyDiaryRoot: View {
    @Environment(DiaryStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.scenePhase) private var phase
    @State private var selected: DiaryScreen = .today
    @State private var editor: DiaryEntry?
    @State private var settings = false
    @State private var personId: String?
    @State private var selectedDay = Date()
    @State private var now = Date()

    var body: some View {
        TabView(selection: $selected) {
            ForEach(DiaryScreen.allCases) { screen in
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {

                            content(screen)
                        }
                        .padding(20)
                    }
                    .background(DiaryStyle.canvas)
                    .navigationTitle(screen.rawValue)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Настройки", systemImage: "gearshape") { settings = true }
                                .labelStyle(.iconOnly)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Добавить", systemImage: "plus") {
                                editor = DiaryEntry(title: "", kind: screen.newKind,
                                                    personId: screen == .children ? personId : nil,
                                                    dueAt: screen == .shopping ? nil : (screen == .calendar ? selectedDay : Date()))
                            }.labelStyle(.iconOnly)
                        }
                    }
                }
                .tabItem { Label(screen.rawValue, systemImage: screen.icon) }
                .tag(screen)
            }
        }
        .tint(DiaryStyle.blue)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .environment(\.timeZone, store.timeZone)
        .sheet(item: $editor) { DiaryEntryEditor(entry: $0) }
        .sheet(isPresented: $settings) { DiarySettingsView() }
        .alert("Не удалось выполнить действие", isPresented: Binding(
            get: { store.diaryError != nil }, set: { if !$0 { store.diaryError = nil } }
        )) { Button("Понятно") { store.diaryError = nil } } message: { Text(store.diaryError ?? "") }
        .task {
            await notifications.refreshAuthorization()
            await refreshReminders()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .onChange(of: store.members) { _, members in
            if !members.contains(where: { $0.id == personId && $0.isChild }) {
                personId = members.first(where: { $0.isChild })?.id
            }
        }
        .onChange(of: store.diaryEntries) { _, _ in Task { await refreshReminders() } }
        .onChange(of: store.timeZone) { _, _ in Task { await refreshReminders() } }
        .onChange(of: phase) { _, value in
            if value == .active { now = Date(); Task { await notifications.refreshAuthorization(); await refreshReminders() } }
        }
        .onChange(of: notifications.pendingEventId) { _, id in
            guard let id else { return }
            selected = .calendar
            if let entry = store.diaryEntries.first(where: { $0.id == id }) {
                selectedDay = entry.nextOccurrence(onOrAfter: Date(), tz: store.timeZone) ?? entry.dueAt ?? Date()
                editor = entry

            }
            notifications.pendingEventId = nil
        }
    }

    @ViewBuilder private func content(_ screen: DiaryScreen) -> some View {
        switch screen {
        case .today:
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "ru_RU"))))
                .font(.title3.weight(.semibold))
            memberStrip(childrenOnly: false)
            card("Планы на сегодня", icon: "calendar", tint: DiaryStyle.blue) {
                dayEntries(now)
            }
            entrySection("Домашние дела", icon: "checkmark.circle", kind: .home,
                         entries: store.diaryEntries.filter { $0.kind == .home && !$0.completed })
            card("Покупки", icon: "basket", tint: .green) {
                let pending = store.diaryEntries.filter { $0.kind == .shopping && !$0.completed }
                Text(pending.isEmpty ? "Всё куплено" : "Осталось купить: \(pending.count)")
                    .foregroundStyle(.secondary)
                Button("Открыть список") { selected = .shopping }
            }
        case .calendar:
            DatePicker("Выберите день", selection: $selectedDay, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(10).background(.white, in: RoundedRectangle(cornerRadius: 18))
            card(selectedDay.formatted(.dateTime.day().month(.wide).weekday(.wide)), icon: "calendar", tint: DiaryStyle.blue) {
                dayEntries(selectedDay)
            }
        case .children:
            memberStrip(childrenOnly: true)
            if store.members.contains(where: { $0.isChild }) {
                ForEach([DiaryKind.school, .homework, .vaccination, .appointment, .growth, .illness, .development], id: \.self) { kind in
                    entrySection(kind.title, icon: kind.icon, kind: kind,
                                 entries: store.diaryEntries.filter { $0.kind == kind && (personId == nil || $0.personId == personId) })
                }
            } else {
                ContentUnavailableView("Добавьте ребёнка", systemImage: "person.badge.plus",
                                       description: Text("Создайте профиль в настройках ежедневника."))
            }
        case .home:
            entrySection("Домашние дела", icon: "checkmark.circle", kind: .home,
                         entries: store.diaryEntries.filter { $0.kind == .home })
            card("Распределение дел", icon: "person.2", tint: .teal) {
                ForEach(store.members) { member in
                    HStack {
                        Text(member.emoji); Text(member.name)
                        Spacer()
                        Text("\(store.diaryEntries.filter { $0.kind == .home && $0.personId == member.id && !$0.completed }.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .shopping:
            ForEach(DiaryEntry.shoppingCategories, id: \.self) { category in
                card(category, icon: "basket", tint: .green) {
                    let entries = store.diaryEntries.filter { $0.kind == .shopping && $0.category == category }
                    if entries.isEmpty { emptyLabel("Список пока пуст") }
                    ForEach(entries) { entry in entryRow(entry) }
                    Button("Добавить покупку", systemImage: "plus") {
                        editor = DiaryEntry(title: "", kind: .shopping, category: category)
                    }.font(.subheadline.weight(.medium))
                }
            }
        }
    }

    private func memberStrip(childrenOnly: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(store.members.filter { !childrenOnly || $0.isChild }) { member in
                    Button {
                        if childrenOnly { personId = member.id }
                    } label: {
                        VStack(spacing: 8) {
                            Text(member.emoji)
                                .font(.system(size: 34)).frame(width: 64, height: 64)
                                .background(DiaryStyle.blue.opacity(0.08), in: Circle())
                            Text(member.name).font(.subheadline.weight(.semibold))
                        }
                        .frame(minWidth: 90).padding(12)
                        .background(personId == member.id && childrenOnly ? DiaryStyle.blue.opacity(0.12) : .white,
                                    in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            if childrenOnly, personId == nil { personId = store.members.first(where: { $0.isChild })?.id }
        }
    }

    private func entrySection(_ title: String, icon: String, kind: DiaryKind, entries: [DiaryEntry]) -> some View {
        card(title, icon: icon, tint: DiaryStyle.tint(kind)) {
            if entries.isEmpty { emptyLabel("Записей пока нет") }
            ForEach(entries) { entry in entryRow(entry) }
            Button("Добавить", systemImage: "plus") {
                editor = DiaryEntry(title: "", kind: kind, personId: kind.isChildEntry ? personId : nil)
            }.font(.subheadline.weight(.medium))
        }
    }

    @ViewBuilder private func dayEntries(_ day: Date) -> some View {
        let entries = store.diaryEntries.filter { $0.kind != .shopping && $0.occurs(on: day, tz: store.timeZone) }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        if entries.isEmpty { emptyLabel("На этот день ничего не запланировано") }
        ForEach(entries) { entry in entryRow(entry) }
    }

    private func entryRow(_ entry: DiaryEntry) -> some View {
        HStack(spacing: 10) {
            if entry.kind == .home || entry.kind == .homework || entry.kind == .shopping {
                Button {
                    var updated = entry; updated.completed.toggle()
                    Task { await store.saveDiaryEntry(updated) }
                } label: {
                    Image(systemName: entry.completed ? "checkmark.square.fill" : "square")
                        .font(.title3).foregroundStyle(entry.completed ? .green : .secondary)
                        .frame(width: 36, height: 44)
                }.buttonStyle(.plain).accessibilityLabel(entry.completed ? "Отметить невыполненным" : "Отметить выполненным")
            } else {
                Image(systemName: entry.kind.icon).foregroundStyle(DiaryStyle.tint(entry.kind)).frame(width: 28)
            }
            Button { editor = entry } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title).font(.subheadline.weight(.medium))
                        .strikethrough(entry.completed).foregroundStyle(entry.completed ? .secondary : .primary)
                    if !entry.quantity.isEmpty { Text(entry.quantity).font(.caption).foregroundStyle(.secondary) }
                    if let due = entry.dueAt {
                        Text(due.formatted(.dateTime.day().month().hour().minute()))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let name = store.members.first(where: { $0.id == entry.personId })?.name {
                        Text(name).font(.caption).foregroundStyle(DiaryStyle.blue)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            if entry.reminderMinutes != nil { Image(systemName: "bell").font(.caption).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(DiaryStyle.tint(entry.kind).opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private func emptyLabel(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 6)
    }

    private func card<Content: View>(_ title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(tint)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.10)))
    }

    private func refreshReminders() async {
        await notifications.reconcileDiary(entries: store.diaryEntries, tz: store.timeZone)
    }
}
