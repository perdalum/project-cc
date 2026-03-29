import Foundation
import Testing
@testable import ProjectCommandAndControl

// MARK: - Project defaults

@Test func projectInitDefaults() {
    let p = Project(name: "Test")
    #expect(!p.id.uuidString.isEmpty)
    #expect(p.created     <= Date())
    #expect(p.name        == "Test")
    #expect(p.category    == "")
    #expect(p.projectType == .classical)
    #expect(p.state       == .new)
    #expect(p.goal        == "")
    #expect(p.log.isEmpty)
    #expect(p.notes.isEmpty)
    #expect(p.touched.isEmpty)
    #expect(p.folder      == nil)
    #expect(p.url         == nil)
    #expect(p.start       == nil)
    #expect(p.end         == nil)
    #expect(p.next        == nil)
    #expect(p.latestReview == nil)
}

// MARK: - ProjectState

@Test func statesRequiringComment() {
    #expect(ProjectState.delegated.requiresComment)
    #expect(ProjectState.waiting.requiresComment)
    #expect(!ProjectState.active.requiresComment)
    #expect(!ProjectState.done.requiresComment)
    #expect(!ProjectState.idea.requiresComment)
    #expect(!ProjectState.new.requiresComment)
    #expect(ProjectState.rejected.requiresComment)
}

@Test func allProjectStatesPresent() {
    let expected: Set<ProjectState> = [.idea, .new, .active, .delegated, .waiting, .rejected, .done]
    #expect(Set(ProjectState.allCases) == expected)
}

// MARK: - Codable round-trips

@Test func projectRoundTrip() throws {
    var p = Project(name: "Round Trip", category: "CHC", projectType: .area, state: .active)
    p.goal = "My goal"
    p.notes.append(Note(text: "A note"))
    p.touched.append(Date())
    p.log.append(LogEntry(oldState: .new, newState: .active, comment: ""))

    let decoded = try roundTrip(p)

    #expect(decoded.id          == p.id)
    // ISO 8601 truncates to whole seconds; allow up to 1 s difference.
    #expect(decoded.created.timeIntervalSince(p.created).magnitude < 1)
    #expect(decoded.name        == p.name)
    #expect(decoded.category    == p.category)
    #expect(decoded.projectType == p.projectType)
    #expect(decoded.state       == p.state)
    #expect(decoded.goal        == p.goal)
    #expect(decoded.notes.count   == 1)
    #expect(decoded.touched.count == 1)
    #expect(decoded.log.count     == 1)
}

@Test func logEntryRoundTrip() throws {
    let entry = LogEntry(oldState: .new, newState: .delegated, comment: "Per takes over")
    let decoded = try roundTrip(entry)
    #expect(decoded.id       == entry.id)
    #expect(decoded.oldState == entry.oldState)
    #expect(decoded.newState == entry.newState)
    #expect(decoded.comment  == entry.comment)
}

@Test func noteRoundTrip() throws {
    let note = Note(text: "Hello world")
    let decoded = try roundTrip(note)
    #expect(decoded.id   == note.id)
    #expect(decoded.text == note.text)
}

@Test func projectOptionalNilsRoundTrip() throws {
    let decoded = try roundTrip(Project(name: "Minimal"))
    #expect(decoded.folder      == nil)
    #expect(decoded.url         == nil)
    #expect(decoded.start       == nil)
    #expect(decoded.end         == nil)
    #expect(decoded.next        == nil)
    #expect(decoded.latestReview == nil)
}

@Test func createdFallsBackForLegacyJSON() throws {
    // JSON produced before `created` existed should decode without error.
    let json = """
    {"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","category":"",
     "projectType":"Classical Project","state":"New","log":[],"modified":"2026-01-01T00:00:00Z",
     "notes":[],"touched":[],"goal":""}
    """.data(using: .utf8)!
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let p = try decoder.decode(Project.self, from: json)
    #expect(p.created == .distantPast)
    #expect(p.name    == "Legacy")
}

// MARK: - Helpers

private func roundTrip<T: Codable>(_ value: T) throws -> T {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(value)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(T.self, from: data)
}
