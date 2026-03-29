import Foundation
import Combine

/// Owns the canonical in-memory project list and is the single writer to disk.
/// Every mutating operation saves immediately.
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []

    let fileURL: URL

    // MARK: Init

    /// Production init: ~/Documents/ProjectCommandAndControl/projects.json
    convenience init() {
        let docs   = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("ProjectCommandAndControl")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.init(fileURL: folder.appendingPathComponent("projects.json"))
    }

    /// Testable init: pass any file URL.
    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    // MARK: Persistence

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let loaded = try? decoder.decode([Project].self, from: data) else { return }
        projects = loaded
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy  = .iso8601
        encoder.outputFormatting      = .prettyPrinted
        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: CRUD

    func add(_ project: Project) {
        projects.append(project)
        save()
    }

    func update(_ project: Project) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        updated.modified = Date()
        projects[i] = updated
        save()
    }

    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    // MARK: Domain operations

    /// Appends a LogEntry and updates state + modified timestamp.
    /// `comment` is mandatory when `newState.requiresComment`.
    func changeState(of id: UUID, to newState: ProjectState, comment: String = "") {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        let entry = LogEntry(oldState: projects[i].state, newState: newState, comment: comment)
        projects[i].log.append(entry)
        projects[i].state    = newState
        projects[i].modified = Date()
        save()
    }

    /// Appends the current timestamp to `touched` and updates `modified`.
    func touch(id: UUID) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].touched.append(Date())
        projects[i].modified = Date()
        save()
    }

    /// Sets (or clears) the URL and updates `modified`.
    func setURL(for id: Project.ID, to url: String?) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].url      = url
        projects[i].modified = Date()
        save()
    }

    /// Sets (or clears) the folder path and updates `modified`.
    func setFolder(for id: Project.ID, to path: String?) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].folder   = path
        projects[i].modified = Date()
        save()
    }

    /// Sets (or clears) the Next date and updates `modified`.
    func setNext(for id: Project.ID, to date: Date?) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].next     = date
        projects[i].modified = Date()
        save()
    }

    /// Appends a timestamped note and updates `modified`.
    func addNote(to id: UUID, text: String) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].notes.append(Note(text: text))
        projects[i].modified = Date()
        save()
    }
}
