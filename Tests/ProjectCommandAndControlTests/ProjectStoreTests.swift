import Foundation
import Testing
@testable import ProjectCommandAndControl

// Swift Testing creates a fresh suite instance per @Test, so init()/deinit act
// as setUp/tearDown. Using a struct means a new tempURL + store for every test.

@Suite struct ProjectStoreTests {
    let store:   ProjectStore
    let tempURL: URL

    init() {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).json")
        store = ProjectStore(fileURL: tempURL)
    }

    // MARK: CRUD

    @Test func addProject() {
        store.add(Project(name: "Alpha"))
        #expect(store.projects.count    == 1)
        #expect(store.projects[0].name  == "Alpha")
    }

    @Test func deleteProject() {
        let p = Project(name: "Delete me")
        store.add(p)
        store.delete(id: p.id)
        #expect(store.projects.isEmpty)
    }

    @Test func deleteUnknownIdIsNoop() {
        store.add(Project(name: "Keep"))
        store.delete(id: UUID())
        #expect(store.projects.count == 1)
    }

    @Test func updateProject() {
        var p = Project(name: "Before")
        store.add(p)
        p.name = "After"
        store.update(p)
        #expect(store.projects[0].name == "After")
    }

    @Test func updateStampsModified() {
        var p = Project(name: "Stamp test")
        store.add(p)
        let before = store.projects[0].modified
        p.name = "Changed"
        store.update(p)
        #expect(store.projects[0].modified >= before)
    }

    @Test func updateUnknownIdIsNoop() {
        store.add(Project(name: "Untouched"))
        store.update(Project(name: "Ghost"))  // different UUID
        #expect(store.projects.count    == 1)
        #expect(store.projects[0].name  == "Untouched")
    }

    // MARK: Persistence

    @Test func saveAndReload() {
        store.add(Project(name: "Persistent", category: "AU"))
        let store2 = ProjectStore(fileURL: tempURL)
        #expect(store2.projects.count       == 1)
        #expect(store2.projects[0].name     == "Persistent")
        #expect(store2.projects[0].category == "AU")
    }

    @Test func loadFromMissingFileGivesEmptyStore() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing_\(UUID().uuidString).json")
        let s = ProjectStore(fileURL: url)
        #expect(s.projects.isEmpty)
    }

    @Test func multipleProjectsRoundTrip() {
        store.add(Project(name: "A", category: "CHC"))
        store.add(Project(name: "B", category: "Arts"))
        store.add(Project(name: "C", category: "Family"))
        let store2 = ProjectStore(fileURL: tempURL)
        #expect(store2.projects.count == 3)
    }

    // MARK: Domain operations

    @Test func changeStateRecordsLogEntry() {
        let p = Project(name: "State test")
        store.add(p)
        store.changeState(of: p.id, to: .active)
        #expect(store.projects[0].state              == .active)
        #expect(store.projects[0].log.count          == 1)
        #expect(store.projects[0].log[0].oldState    == .new)
        #expect(store.projects[0].log[0].newState    == .active)
        #expect(store.projects[0].log[0].comment     == "")
    }

    @Test func changeStateWithComment() {
        let p = Project(name: "Delegated")
        store.add(p)
        store.changeState(of: p.id, to: .delegated, comment: "Per handles this")
        #expect(store.projects[0].log[0].comment == "Per handles this")
    }

    @Test func changeStateUpdatesModified() {
        let p = Project(name: "Modified check")
        store.add(p)
        let before = store.projects[0].modified
        store.changeState(of: p.id, to: .active)
        #expect(store.projects[0].modified >= before)
    }

    @Test func touch() {
        let p = Project(name: "Touch me")
        store.add(p)
        #expect(store.projects[0].touched.count == 0)
        store.touch(id: p.id)
        store.touch(id: p.id)
        #expect(store.projects[0].touched.count == 2)
    }

    @Test func addNote() {
        let p = Project(name: "Notes test")
        store.add(p)
        store.addNote(to: p.id, text: "First note")
        #expect(store.projects[0].notes.count    == 1)
        #expect(store.projects[0].notes[0].text  == "First note")
    }

    @Test func addNoteUpdatesModified() {
        let p = Project(name: "Modified via note")
        store.add(p)
        let before = store.projects[0].modified
        store.addNote(to: p.id, text: "hi")
        #expect(store.projects[0].modified >= before)
    }
}
