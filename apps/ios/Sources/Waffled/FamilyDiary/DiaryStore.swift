import Foundation
import Observation

@MainActor
@Observable
final class DiaryStore {
    private struct Snapshot: Codable {
        var version = 1
        var members: [DiaryMember] = []
        var entries: [DiaryEntry] = []
    }

    private(set) var diaryEntries: [DiaryEntry] = []
    private(set) var members: [DiaryMember] = []
    private(set) var lastSavedAt: Date?
    var diaryError: String?
    var timeZone: TimeZone { .current }
    private let directory: URL
    private var readable = true
    private var file: URL { directory.appendingPathComponent("diary.json") }
    private var backup: URL { directory.appendingPathComponent("diary.backup.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("FamilyDiary", isDirectory: true)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let snapshot = try decode(file)
            members = snapshot.members; diaryEntries = snapshot.entries
        } catch {
            if let snapshot = try? decode(backup) {
                members = snapshot.members; diaryEntries = snapshot.entries
                diaryError = "Восстановлена предыдущая сохранённая копия ежедневника."
            } else {
                readable = false
                diaryError = "Не удалось открыть сохранённый ежедневник. Файл сохранён без изменений."
            }
        }
    }

    private func decode(_ url: URL) throws -> Snapshot {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        guard snapshot.version == 1 else { throw CocoaError(.coderReadCorrupt) }
        return snapshot
    }

    private func commit(entries: [DiaryEntry], people: [DiaryMember]) -> Bool {
        guard readable else {
            diaryError = "Данные не изменены: сначала нужно восстановить сохранённый ежедневник."
            return false
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(members: people, entries: entries))
            if let old = try? Data(contentsOf: file), (try? decode(file)) != nil {
                try old.write(to: backup, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            }
            try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            diaryEntries = entries; members = people; lastSavedAt = Date(); diaryError = nil
            return true
        } catch {
            diaryError = "Не удалось сохранить изменения на iPhone. Проверьте свободное место и попробуйте ещё раз."
            return false
        }
    }

    @discardableResult
    func saveDiaryEntry(_ entry: DiaryEntry) async -> Bool {
        var entry = entry
        entry.title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.title.isEmpty else { diaryError = "Введите название."; return false }
        var entries = diaryEntries
        if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry }
        else { entries.append(entry) }
        return commit(entries: entries, people: members)
    }

    @discardableResult
    func deleteDiaryEntry(_ id: String) async -> Bool {
        commit(entries: diaryEntries.filter { $0.id != id }, people: members)
    }

    @discardableResult
    func saveMember(_ member: DiaryMember) -> Bool {
        var member = member
        member.name = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !member.name.isEmpty else { diaryError = "Введите имя."; return false }
        var people = members
        if let index = people.firstIndex(where: { $0.id == member.id }) { people[index] = member }
        else { people.append(member) }
        return commit(entries: diaryEntries, people: people)
    }

    @discardableResult
    func deleteMember(_ id: String) -> Bool {
        let entries = diaryEntries.map { entry in
            var entry = entry
            if entry.personId == id { entry.personId = nil }
            return entry
        }
        return commit(entries: entries, people: members.filter { $0.id != id })
    }
}
