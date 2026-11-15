import Testing
import Foundation
@testable import Waffled

@MainActor
struct DiaryStoreTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    @Test func testRecordsAndChildrenSurviveRelaunch() async {
        let store = DiaryStore(directory: directory)
        #expect(store.saveMember(DiaryMember(name: "Милана", isChild: true)))
        let entry = DiaryEntry(title: "Молоко", kind: .shopping, quantity: "2 л")
        #expect(await store.saveDiaryEntry(entry))
        let reopened = DiaryStore(directory: directory)
        #expect(reopened.diaryEntries == [entry])
        #expect(reopened.members.map(\.name) == ["Милана"])
        #expect(await reopened.deleteDiaryEntry(entry.id))
        #expect(DiaryStore(directory: directory).diaryEntries.isEmpty)
    }

    @Test func testFailedWriteDoesNotPretendItSaved() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: file)
        let store = DiaryStore(directory: file)
        #expect(await store.saveDiaryEntry(DiaryEntry(title: "Дело", kind: .home)) == false)
        #expect(store.diaryEntries.isEmpty)
        #expect(store.diaryError != nil)
    }

    @Test func testCorruptStoreIsNotOverwritten() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("diary.json")
        let corrupt = Data("broken".utf8)
        try corrupt.write(to: file)
        let store = DiaryStore(directory: directory)
        #expect(await store.saveDiaryEntry(DiaryEntry(title: "Дело", kind: .home)) == false)
        #expect(try Data(contentsOf: file) == corrupt)
    }

    @Test func testDeletingChildKeepsNotesAndClearsAssignment() async {
        let store = DiaryStore(directory: directory)
        let member = DiaryMember(name: "Малыш", isChild: true)
        #expect(store.saveMember(member))
        #expect(await store.saveDiaryEntry(DiaryEntry(title: "Приём", kind: .appointment, personId: member.id)))
        #expect(store.deleteMember(member.id))
        #expect(store.diaryEntries.count == 1)
        #expect(store.diaryEntries.first?.personId == nil)
    }
}
