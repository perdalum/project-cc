import Foundation
import Combine

/// Owns the canonical in-memory project list and is the single writer to disk.
/// Every mutating operation saves immediately.
@MainActor
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []

    @Published private(set) var fileURL: URL
    private var cancellables: Set<AnyCancellable> = []

    // MARK: Init

    /// Production init: ~/Documents/ProjectCommandAndControl/projects.json
    convenience init() {
        self.init(fileURL: AppSettings.defaultPersistentStorageURL)
    }

    convenience init(settings: AppSettings) {
        self.init(fileURL: settings.persistentStorageURL)
        settings.$persistentStoragePath
            .removeDuplicates()
            .sink { [weak self, weak settings] _ in
                guard let self, let settings else { return }
                self.switchToFile(settings.persistentStorageURL)
            }
            .store(in: &cancellables)
    }

    /// Testable init: pass any file URL.
    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    // MARK: Persistence

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            projects = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let loaded = try? decoder.decode([Project].self, from: data) else {
            projects = []
            return
        }
        projects = loaded
    }

    func save() {
        prepareParentDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy  = .iso8601
        encoder.outputFormatting      = .prettyPrinted
        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func switchToFile(_ url: URL) {
        guard fileURL != url else { return }
        fileURL = url
        load()
    }

    private func prepareParentDirectory() {
        let folder = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    // MARK: CRUD

    func add(_ project: Project) {
        projects.append(project)
        save()
    }

    func update(_ project: Project) {
        guard let i = projects.firstIndex(where: { $0.id == project.id }) else { return }
        var updated = project
        let now = Date()
        updated.modified = now
        updated.touched.append(now)
        projects[i] = updated
        save()
    }

    func delete(id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    // MARK: Domain operations

    /// Stamps both `modified` and `touched` with the current time.
    private func stampBoth(_ i: Int) {
        let now = Date()
        projects[i].modified = now
        projects[i].touched.append(now)
    }

    /// Appends a LogEntry and updates state + modified timestamp.
    /// `comment` is mandatory when `newState.requiresComment`.
    /// When a comment is provided it is also mirrored to the Note log.
    func changeState(of id: UUID, to newState: ProjectState, comment: String = "") {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        let oldState = projects[i].state
        let entry = LogEntry(oldState: oldState, newState: newState, comment: comment)
        projects[i].log.append(entry)
        projects[i].state = newState
        if !comment.isEmpty {
            let noteText = "State change: \(oldState.rawValue) → \(newState.rawValue): \(comment)"
            projects[i].notes.append(Note(text: noteText))
        }
        stampBoth(i)
        save()
    }

    /// Appends the current timestamp to `touched` and updates `modified`.
    func touch(id: UUID) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        stampBoth(i)
        save()
    }

    /// Sets (or clears) the URL and updates `modified` and `touched`.
    func setURL(for id: Project.ID, to url: String?) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].url = url
        stampBoth(i)
        save()
    }

    /// Sets (or clears) the folder path and updates `modified` and `touched`.
    func setFolder(for id: Project.ID, to path: String?) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].folder = path
        stampBoth(i)
        save()
    }

    /// Sets (or clears) the Next date and updates `modified` and `touched`.
    func setNext(for id: Project.ID, to date: Date?) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].next = date
        stampBoth(i)
        save()
    }

    /// Appends a timestamped note and updates `modified` and `touched`.
    func addNote(to id: UUID, text: String) {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].notes.append(Note(text: text))
        stampBoth(i)
        save()
    }
}
