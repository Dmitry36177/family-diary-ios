import Foundation

struct DiaryMember: Identifiable, Codable, Equatable, Sendable {
    var id = UUID().uuidString.lowercased()
    var name: String
    var isChild: Bool
    var emoji: String { isChild ? "🧒" : "👤" }
}
