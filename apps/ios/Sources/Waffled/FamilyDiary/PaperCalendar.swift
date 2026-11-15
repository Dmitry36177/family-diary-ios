import SwiftUI

struct PaperCalendar: View {
    @Binding var selectedDay: Date
    let entries: [DiaryEntry]
    let timeZone: TimeZone
    @State private var month: Date = Date()
    private var calendar: Calendar { DiaryDates.calendar }
    private var grid: [Date] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let offset = (calendar.component(.weekday, from: start) + 5) % 7
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0 - offset, to: start) }
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 36, height: 40) }.accessibilityLabel("Предыдущий месяц")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "ru_RU"))))
                    .font(Paper.title(20))
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 36, height: 40) }.accessibilityLabel("Следующий месяц")
            }.foregroundStyle(Paper.gold)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(DiaryDates.labels, id: \.self) { Text($0).font(.system(size: 12, design: .serif)).foregroundStyle(Paper.muted).frame(height: 20) }
                ForEach(grid, id: \.self) { day in
                    let current = calendar.isDate(day, equalTo: month, toGranularity: .month)
                    let selected = calendar.isDate(day, inSameDayAs: selectedDay)
                    Button { selectedDay = day } label: {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day))").font(.system(size: 16, design: .serif))
                            Circle().fill(entries.contains { $0.occurs(on: day, tz: timeZone) } ? Paper.rose : .clear).frame(width: 3, height: 3)
                        }
                        .frame(maxWidth: .infinity).frame(height: 39)
                        .foregroundStyle(current ? (selected ? Paper.rose : Paper.ink) : Paper.muted.opacity(0.4))
                        .background(selected ? Paper.rose.opacity(0.04) : .clear, in: Circle())
                        .overlay(Circle().stroke(selected ? Paper.rose.opacity(0.8) : .clear, lineWidth: 1.2).padding(2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(DiaryDates.day(day))
                    .accessibilityIdentifier("calendar.date.\(DiaryDates.key(day))")
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear { month = selectedDay }
        .onChange(of: selectedDay) { _, value in if !calendar.isDate(value, equalTo: month, toGranularity: .month) { month = value } }
    }
    private func move(_ offset: Int) { if let date = calendar.date(byAdding: .month, value: offset, to: month) { month = date } }
}
