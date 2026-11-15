import SwiftUI

enum Paper {
    static let page = Color(red: 0.988, green: 0.969, blue: 0.922)
    static let ink = Color(red: 0.30, green: 0.26, blue: 0.21)
    static let muted = Color(red: 0.55, green: 0.48, blue: 0.38)
    static let sage = Color(red: 0.43, green: 0.50, blue: 0.37)
    static let rose = Color(red: 0.67, green: 0.47, blue: 0.42)
    static let gold = Color(red: 0.62, green: 0.49, blue: 0.30)
    static let line = Color(red: 0.78, green: 0.70, blue: 0.55)
    static func title(_ size: CGFloat = 24) -> Font { .system(size: size, weight: .regular, design: .serif).italic() }
}

enum DiaryStyle {
    static let blue = Paper.sage
    static func tint(_ kind: DiaryKind) -> Color {
        switch kind {
        case .appointment, .vaccination, .illness: Paper.rose
        case .home, .shopping, .growth: Paper.sage
        default: Paper.gold
        }
    }
}

struct PaperBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Paper.page
                Canvas { context, size in
                    var rules = Path()
                    for y in stride(from: 30.0, through: size.height, by: 31.0) {
                        rules.move(to: CGPoint(x: 12, y: y)); rules.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(rules, with: .color(Paper.line.opacity(0.17)), lineWidth: 0.6)
                    var margin = Path()
                    margin.move(to: CGPoint(x: 25, y: 0)); margin.addLine(to: CGPoint(x: 25, y: size.height))
                    context.stroke(margin, with: .color(Paper.rose.opacity(0.21)), lineWidth: 0.7)
                }
                LinearGradient(colors: [Color(red: 0.44, green: 0.34, blue: 0.23), Paper.gold.opacity(0.7), Paper.page], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.ignoresSafeArea()
    }
}

struct PaperSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Paper.gold
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 17)) }
                Text(title).font(Paper.title(19))
            }.foregroundStyle(tint)
                .padding(.vertical, 5).padding(.horizontal, 5)
                .background(tint.opacity(0.10))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }
}

struct PaperPrimary: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .medium))
            .foregroundStyle(Paper.page)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Paper.sage.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Paper.ink.opacity(0.12)))
    }
}

struct PaperCaption: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 13, design: .serif)).foregroundStyle(Paper.muted) }
}

enum DiaryDates {
    static let weekdays = [2,3,4,5,6,7,1]
    static let labels = ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
    static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian); value.firstWeekday = 2; return value
    }
    static func key(_ day: Date) -> String {
        let c = calendar.dateComponents([.year,.month,.day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func day(_ date: Date) -> String { date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "ru_RU"))) }
    static func time(_ date: Date) -> String { date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "ru_RU"))) }
    static func weekdaySummary(_ entry: DiaryEntry) -> String {
        if let selected = entry.weekdays, !selected.isEmpty {
            return zip(weekdays, labels).filter { selected.contains($0.0) }.map(\.1).joined(separator: ", ")
        }
        return entry.repeatRule.title
    }
}
