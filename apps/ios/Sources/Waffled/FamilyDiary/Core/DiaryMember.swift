import Foundation

struct DiaryMember: Identifiable, Codable, Equatable, Sendable {
    var id = UUID().uuidString.lowercased()
    var name: String
    var isChild: Bool
    var birthday: Date?
    var schoolClass: String?
    var emoji: String { isChild ? "🧒" : "👤" }
}
