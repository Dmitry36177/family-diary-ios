import SwiftUI

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
}

struct FamilyDiaryRoot: View {
    @Environment(DiaryStore.self) private var store
    @Environment(NotificationManager.self) private var notifications
    @Environment(\.scenePhase) private var phase
    @State private var selected: DiaryScreen = .today
    @State private var editor: DiaryEntry?
    @State private var memberEditor: DiaryMember?
    @State private var settings = false
    @State private var childId: String?
    @State private var calendarPerson: String?
    @State private var selectedDay = Date()
    @State private var homeDay = Date()
    @State private var weekMode = true
    @State private var category = DiaryEntry.shoppingCategories[0]
    @State private var quickProduct = ""
    @State private var now = Date()
    private var child: DiaryMember? { store.members.first { $0.id == childId } ?? store.members.first { $0.isChild } }
    private var todayEntries: [DiaryEntry] { entries(on: now) }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        content
                    }.padding(.leading, 30).padding(.trailing, 22).padding(.top, 8).padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bookmarks }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Paper.sage).foregroundStyle(Paper.ink)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .environment(\.timeZone, store.timeZone)
        .sheet(item: $editor) { DiaryEntryEditor(entry: $0) }
        .sheet(item: $memberEditor) { DiaryMemberEditor(member: $0) }
        .sheet(isPresented: $settings) { DiarySettingsView() }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { store.diaryError != nil }, set: { if !$0 { store.diaryError = nil } })) {
            Button("Понятно") { store.diaryError = nil }
        } message: { Text(store.diaryError ?? "") }
        .task { await notifications.refreshAuthorization(); await refreshReminders() }
        .onChange(of: store.diaryEntries) { _, _ in Task { await refreshReminders() } }
        .onChange(of: phase) { _, value in
            if value == .active { now = Date(); Task { await notifications.refreshAuthorization(); await refreshReminders() } }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in Task { await refreshReminders() } }
        .onChange(of: notifications.pendingEventId) { _, id in
            guard let id, let entry = store.diaryEntries.first(where: { $0.id == id }) else { return }
            selected = .calendar; selectedDay = entry.dueAt ?? Date(); editor = entry
            notifications.pendingEventId = nil
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(selected.rawValue).font(Paper.title(29)).accessibilityAddTraits(.isHeader).accessibilityIdentifier("page.title")
            Spacer()
            if selected == .today {
                Button { settings = true } label: { Image(systemName: "gearshape").frame(width: 38, height: 40) }
                    .accessibilityLabel("Настройки")
            } else {
                Button(action: primaryAction) {
                    Label(actionTitle, systemImage: "plus").font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 10).frame(minHeight: 40)
                        .background(Paper.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }.accessibilityIdentifier("primary.\(selected.id)")
            }
        }.foregroundStyle(Paper.gold)
    }
    private var actionTitle: String {
        switch selected {
        case .today: "Настройки"
        case .calendar: "Напомнить"
        case .children: "Ребёнок"
        case .home: "Дело"
        case .shopping: "Товар"
        }
    }
    private func primaryAction() {
        switch selected {
        case .today: settings = true
        case .children: memberEditor = DiaryMember(name: "", isChild: true)
        case .calendar: editor = newEntry(.event, day: selectedDay, reminder: true)
        case .home:
            var entry = newEntry(.home, day: weekMode ? homeDay : now)
            if weekMode { entry.repeatRule = .weekly; entry.weekdays = [DiaryDates.calendar.component(.weekday, from: homeDay)] }
            editor = entry
        case .shopping: editor = DiaryEntry(title: "", kind: .shopping, category: category)
        }
    }
    private func newEntry(_ kind: DiaryKind, day: Date, reminder: Bool = false, person: String? = nil) -> DiaryEntry {
        let calendar = DiaryDates.calendar
        let due = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? day
        return DiaryEntry(title: "", kind: kind, personId: person, dueAt: due, reminderMinutes: reminder ? 15 : nil)
    }

    private var bookmarks: some View {
        HStack(spacing: 3) {
            ForEach(DiaryScreen.allCases) { screen in
                Button { selected = screen } label: {
                    VStack(spacing: 5) {
                        Image(systemName: screen.icon).font(.system(size: 18))
                        Text(screen.rawValue).font(.system(size: 10, design: .serif)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity).frame(height: 53)
                    .foregroundStyle(selected == screen ? Paper.sage : Paper.muted)
                    .background(selected == screen ? Color(red: 0.87, green: 0.89, blue: 0.79) : Paper.page.opacity(0.65), in: UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5))
                    .overlay(alignment: .top) { Rectangle().fill((selected == screen ? Paper.sage : Paper.gold).opacity(0.45)).frame(height: 1) }
                }
                .buttonStyle(.plain).accessibilityIdentifier("tab.\(screen.rawValue)")
                .accessibilityAddTraits(selected == screen ? [.isSelected] : [])
            }
        }.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)
            .background(Color(red: 0.91, green: 0.87, blue: 0.78).ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder private var content: some View {
        switch selected {
        case .today: today
        case .calendar: calendarPage
        case .children: childrenPage
        case .home: homePage
        case .shopping: shoppingPage
        }
    }

    private var today: some View {
        VStack(alignment: .leading, spacing: 20) {
            PaperCaption(text: now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "ru_RU"))))
            peopleStrip(childrenOnly: false)
            if let next = todayEntries.first(where: { !$0.isCompleted(on: now, tz: store.timeZone) && ($0.dueAt.map { DiaryDates.time($0) >= DiaryDates.time(now) } ?? false) }) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("БЛИЖАЙШЕЕ · \(next.dueAt.map(DiaryDates.time) ?? "")").font(.system(size: 11, weight: .medium)).tracking(1)
                    Text(next.title).font(Paper.title(23))
                    owner(next.personId)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.94, green: 0.89, blue: 0.69))
                    .overlay(alignment: .top) { Rectangle().fill(Paper.line.opacity(0.6)).frame(width: 64, height: 14).rotationEffect(.degrees(3)).offset(y: -7) }
                    .rotationEffect(.degrees(-1)).shadow(color: Paper.gold.opacity(0.15), radius: 3, y: 3)
            }
            PaperSection(title: "Сегодня в планах", icon: "calendar") {
                if todayEntries.isEmpty { empty("На сегодня планов пока нет") }
                ForEach(todayEntries.filter { $0.kind != .home }) { entry in entryRow(entry, day: now) }
                Button("Запланировать день", systemImage: "plus") { selected = .calendar; selectedDay = now }
                    .font(.subheadline)
            }
            PaperSection(title: "Дела дома", icon: "checkmark.square", tint: Paper.sage) {
                let tasks = store.diaryEntries.filter { $0.kind == .home && ($0.dueAt == nil || $0.occurs(on: now, tz: store.timeZone)) }
                if tasks.isEmpty { empty("Домашних дел на сегодня нет") }
                ForEach(tasks) { entry in entryRow(entry, day: now) }
            }
            HStack {
                Label("Купить: \(store.diaryEntries.filter { $0.kind == .shopping && !$0.completed }.count)", systemImage: "basket").font(.subheadline)
                Spacer(); Button("Открыть список") { selected = .shopping }.font(.subheadline)
            }
        }
    }

    private var calendarPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            PaperCalendar(selectedDay: $selectedDay, entries: store.diaryEntries.filter { $0.kind != .shopping }, timeZone: store.timeZone)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    filter("Все", selected: calendarPerson == nil) { calendarPerson = nil }
                    ForEach(store.members) { person in filter(person.name, selected: calendarPerson == person.id) { calendarPerson = person.id } }
                }
            }
            PaperSection(title: DiaryDates.day(selectedDay), icon: "calendar") {
                let visible = entries(on: selectedDay).filter { calendarPerson == nil || $0.personId == calendarPerson }
                if visible.isEmpty { empty("На этот день пока нет планов") }
                ForEach(visible) { entry in entryRow(entry, day: selectedDay) }
                Button { editor = newEntry(.event, day: selectedDay, reminder: true) } label: {
                    Label("Напоминание на \(DiaryDates.day(selectedDay))", systemImage: "bell")
                }.buttonStyle(PaperPrimary()).accessibilityIdentifier("calendar.addReminder")
            }
        }
    }

    private var childrenPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            peopleStrip(childrenOnly: true)
            if let child {
                HStack {
                    Text(child.name).font(Paper.title(21)); Spacer()
                    Button("Профиль") { memberEditor = child }.font(.subheadline)
                }
                childSection("Школа", kinds: [.school,.homework], child: child, tint: Paper.gold)
                childSection("Здоровье", kinds: [.appointment,.growth,.illness], child: child, tint: Paper.rose)
                childSection("Прививки", kinds: [.vaccination], child: child, tint: Paper.sage)
                childSection("Развитие", kinds: [.development], child: child, tint: Paper.sage)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.rectangle.badge.plus").font(.system(size: 42)).foregroundStyle(Paper.gold)
                    Text("Страница вашего ребёнка").font(Paper.title(22))
                    PaperCaption(text: "Создайте профиль — здесь будут школа, здоровье и расписание ребёнка.")
                    Button("Добавить ребёнка", systemImage: "plus") { memberEditor = DiaryMember(name: "", isChild: true) }
                        .buttonStyle(PaperPrimary()).accessibilityIdentifier("children.addChild")
                }.padding(.vertical, 30)
            }
        }
    }
    private func childSection(_ title: String, kinds: [DiaryKind], child: DiaryMember, tint: Color) -> some View {
        PaperSection(title: title, icon: kinds[0].icon, tint: tint) {
            ForEach(kinds, id: \.self) { kind in
                let items = store.diaryEntries.filter { $0.personId == child.id && $0.kind == kind }
                DisclosureGroup {
                    ForEach(items) { entry in entryRow(entry, day: entry.dueAt ?? now) }
                    Button("Добавить: \(kind.title.lowercased())", systemImage: "plus") {
                        editor = DiaryEntry(title: "", kind: kind, personId: child.id)
                    }.font(.subheadline).padding(.vertical, 7)
                } label: {
                    HStack {
                        Label(kind.title, systemImage: kind.icon).font(.subheadline)
                        Spacer(); Text("\(items.count)").font(.caption).foregroundStyle(Paper.muted)
                    }
                }.padding(.vertical, 5)
            }
        }
    }

    private var homePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Вид домашних дел", selection: $weekMode) {
                Text("Сегодня").tag(false); Text("Расписание недели").tag(true)
            }.pickerStyle(.segmented)
            if weekMode {
                HStack(spacing: 3) {
                    ForEach(0..<7) { index in
                        let day = weekDay(index)
                        Button { homeDay = day } label: {
                            VStack(spacing: 6) {
                                Text(DiaryDates.labels[index]).font(.system(size: 12, design: .serif))
                                Text("\(DiaryDates.calendar.component(.day, from: day))").font(.system(size: 17, design: .serif))
                            }.frame(maxWidth: .infinity).frame(height: 58)
                                .background(DiaryDates.calendar.isDate(day, inSameDayAs: homeDay) ? Paper.sage.opacity(0.19) : Paper.gold.opacity(0.06))
                        }.buttonStyle(.plain).accessibilityIdentifier("home.weekday.\(DiaryDates.weekdays[index])")
                    }
                }
            }
            PaperSection(title: weekMode ? "\(DiaryDates.day(homeDay)) · недельный график" : "Дела на сегодня", icon: weekMode ? "repeat" : "checkmark.square", tint: Paper.sage) {
                let list = store.diaryEntries.filter { $0.kind == .home && (weekMode ? ($0.repeatRule == .weekly && $0.occurs(on: homeDay, tz: store.timeZone)) : ($0.dueAt == nil || $0.occurs(on: now, tz: store.timeZone))) }
                if list.isEmpty { empty(weekMode ? "Добавьте дела, которые повторяются по неделям" : "На сегодня домашних дел нет") }
                ForEach(list) { entry in entryRow(entry, day: weekMode ? homeDay : now, schedule: weekMode) }
                Button(action: primaryAction) {
                    Label(weekMode ? "Дело в недельный график" : "Добавить домашнее дело", systemImage: "plus")
                }.buttonStyle(PaperPrimary()).accessibilityIdentifier("home.addSchedule")
            }
            if weekMode { PaperCaption(text: "Выберите дни и время для каждого дела. График будет повторяться каждую неделю.") }
            PaperSection(title: "Ответственные", icon: "person.2", tint: Paper.gold) {
                ForEach(store.members) { person in
                    HStack { owner(person.id); Spacer(); PaperCaption(text: "Дел: \(store.diaryEntries.filter { $0.kind == .home && $0.personId == person.id }.count)") }
                }
                Button("Добавить профиль", systemImage: "person.badge.plus") { memberEditor = DiaryMember(name: "", isChild: false) }.font(.subheadline)
            }
        }
    }
    private func weekDay(_ index: Int) -> Date {
        let calendar = DiaryDates.calendar
        let weekday = (calendar.component(.weekday, from: now) + 5) % 7
        return calendar.date(byAdding: .day, value: index - weekday, to: calendar.startOfDay(for: now)) ?? now
    }

    private var shoppingPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 5) {
                ForEach(Array(DiaryEntry.shoppingCategories.enumerated()), id: \.element) { index, value in
                    Button { category = value } label: {
                        VStack(spacing: 7) {
                            Image(systemName: ["carrot","figure.child","sparkles","house"][index]).font(.system(size: 19))
                            Text(["Продукты","Детям","Для уборки","Для дома"][index]).font(.system(size: 10, design: .serif)).lineLimit(2)
                        }.frame(maxWidth: .infinity).frame(height: 68)
                            .background(category == value ? Paper.sage.opacity(0.17) : Paper.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                    }.buttonStyle(.plain).accessibilityLabel(value)
                }
            }
            PaperSection(title: category, icon: "basket", tint: Paper.sage) {
                let items = store.diaryEntries.filter { $0.kind == .shopping && $0.category == category }
                if items.isEmpty { empty("Список пока пуст") }
                ForEach(items) { entry in entryRow(entry, day: now) }
                HStack {
                    TextField("Добавить товар", text: $quickProduct).submitLabel(.done).onSubmit { addQuickProduct() }
                    Button(action: addQuickProduct) { Image(systemName: "plus").frame(width: 40, height: 40) }
                        .disabled(quickProduct.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityLabel("Добавить товар")
                }.font(.subheadline).padding(.horizontal, 9).background(Paper.gold.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
            }
            PaperCaption(text: "Осталось купить: \(store.diaryEntries.filter { $0.kind == .shopping && !$0.completed }.count)")
            Button(action: primaryAction) { Label("Товар с количеством", systemImage: "plus") }.buttonStyle(PaperPrimary())
        }
    }
    private func addQuickProduct() {
        let title = quickProduct.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let entry = DiaryEntry(title: title, kind: .shopping, category: category)
        Task { if await store.saveDiaryEntry(entry) { quickProduct = "" } }
    }

    private func peopleStrip(childrenOnly: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.members.filter { !childrenOnly || $0.isChild }) { person in
                    Button { if childrenOnly { childId = person.id } } label: {
                        VStack(spacing: 8) {
                            Text(person.emoji).font(.system(size: childrenOnly ? 40 : 26))
                                .frame(width: childrenOnly ? 90 : 50, height: childrenOnly ? 76 : 50)
                                .background(Paper.sage.opacity(0.12), in: RoundedRectangle(cornerRadius: childrenOnly ? 2 : 25))
                            Text(person.name).font(.system(size: childrenOnly ? 16 : 12, design: .serif)).italic()
                            if childrenOnly { PaperCaption(text: personDetail(person)) }
                        }.padding(childrenOnly ? 9 : 0)
                            .background(childrenOnly ? Paper.page : .clear)
                            .overlay(alignment: .bottom) { if childrenOnly && child?.id == person.id { Rectangle().fill(Paper.sage.opacity(0.4)).frame(height: 2) } }
                    }.buttonStyle(.plain).accessibilityIdentifier("profile.\(person.id)")
                }
            }.padding(.vertical, 4)
        }
    }
    private func personDetail(_ person: DiaryMember) -> String {
        var details: [String] = []
        if let birthday = person.birthday {
            let months = DiaryDates.calendar.dateComponents([.month], from: birthday, to: now).month ?? 0
            details.append(months < 12 ? "\(max(0, months)) мес." : "\(months / 12) лет")
        }
        if let school = person.schoolClass, !school.isEmpty { details.append(school) }
        return details.joined(separator: " · ")
    }
    private func filter(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 13, design: .serif)).padding(.horizontal, 9).padding(.vertical, 8)
                .background(selected ? Paper.sage.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 3)) }.buttonStyle(.plain)
    }
    private func entries(on day: Date) -> [DiaryEntry] {
        store.diaryEntries.filter { $0.kind != .shopping && $0.occurs(on: day, tz: store.timeZone) }
            .sorted { ($0.dueAt.map(DiaryDates.time) ?? "") < ($1.dueAt.map(DiaryDates.time) ?? "") }
    }
    private func owner(_ id: String?) -> some View {
        Group {
            if let person = store.members.first(where: { $0.id == id }) {
                Text("\(person.emoji) \(person.name)").font(.system(size: 12, design: .serif)).foregroundStyle(Paper.muted)
            }
        }
    }
    private func entryRow(_ entry: DiaryEntry, day: Date, schedule: Bool = false) -> some View {
        let done = entry.isCompleted(on: day, tz: store.timeZone)
        return HStack(spacing: 9) {
            if !schedule && [.home,.homework,.shopping].contains(entry.kind) {
                Button {
                    var edited = entry; edited.toggleCompletion(on: day, tz: store.timeZone)
                    Task { await store.saveDiaryEntry(edited) }
                } label: { Image(systemName: done ? "checkmark.square" : "square").font(.system(size: 21)).frame(width: 29, height: 44) }
                    .buttonStyle(.plain).accessibilityLabel(done ? "Отметить невыполненным" : "Отметить выполненным")
            } else if let due = entry.dueAt {
                Text(DiaryDates.time(due)).font(.system(size: 13, design: .serif)).italic().foregroundStyle(Paper.gold).frame(width: 43, alignment: .leading)
            }
            Button { editor = entry } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title).font(.system(size: 16, design: .serif)).strikethrough(done).foregroundStyle(done ? Paper.muted : Paper.ink)
                    if !entry.quantity.isEmpty { PaperCaption(text: entry.quantity) }
                    owner(entry.personId)
                    if entry.repeatRule != .never { Label(DiaryDates.weekdaySummary(entry), systemImage: "repeat").font(.system(size: 11)).foregroundStyle(Paper.muted) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            if entry.reminderMinutes != nil { Image(systemName: "bell").font(.caption).foregroundStyle(Paper.gold) }
        }.padding(.vertical, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Paper.line.opacity(0.45)).frame(height: 0.6) }
    }
    private func empty(_ text: String) -> some View { PaperCaption(text: text).padding(.vertical, 8) }
    private func refreshReminders() async { await notifications.reconcileDiary(entries: store.diaryEntries, tz: store.timeZone) }
}
