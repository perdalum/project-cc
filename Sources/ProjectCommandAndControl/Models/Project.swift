import Foundation

// MARK: - Enums

enum ProjectState: String, Codable, CaseIterable, Hashable, Comparable {
    case idea      = "Idea"
    case new       = "New"
    case active    = "Active"
    case delegated = "Delegated"
    case waiting   = "Waiting"
    case rejected  = "Rejected"
    case done      = "Done"

    /// State changes to Delegated, Waiting, or Rejected require a comment explaining who/why.
    var requiresComment: Bool {
        self == .delegated || self == .waiting || self == .rejected
    }

    static func < (lhs: ProjectState, rhs: ProjectState) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

enum ProjectType: String, Codable, CaseIterable, Hashable {
    case classical = "Classical Project"
    case area      = "Area of Responsibility"
}

// MARK: - Supporting value types

struct LogEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let oldState: ProjectState
    let newState: ProjectState
    let comment: String

    init(date: Date = Date(), oldState: ProjectState, newState: ProjectState, comment: String) {
        self.id       = UUID()
        self.date     = date
        self.oldState = oldState
        self.newState = newState
        self.comment  = comment
    }
}

struct Note: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    var text: String

    init(date: Date = Date(), text: String) {
        self.id   = UUID()
        self.date = date
        self.text = text
    }
}

// MARK: - Project

struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    let created: Date   // UR — stamped once at creation
    var name: String
    var category: String
    var projectType: ProjectType
    var state: ProjectState
    var log: [LogEntry]
    var start: Date?
    var end: Date?
    var modified: Date
    var folder: String?
    var notes: [Note]
    var touched: [Date]
    var latestReview: Date?
    var next: Date?
    var url: String?
    var goal: String

    init(
        name: String,
        category: String = "",
        projectType: ProjectType = .classical,
        state: ProjectState = .new
    ) {
        self.id          = UUID()
        self.created     = Date()
        self.name        = name
        self.category    = category
        self.projectType = projectType
        self.state       = state
        self.log         = []
        self.start       = nil
        self.end         = nil
        self.modified    = Date()
        self.folder      = nil
        self.notes       = []
        self.touched     = []
        self.latestReview = nil
        self.next        = nil
        self.url         = nil
        self.goal        = ""
    }

    // Custom decoder: `created` falls back to .distantPast for JSON saved before
    // this property was introduced, keeping existing data loadable.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self,            forKey: .id)
        created     = try c.decodeIfPresent(Date.self,   forKey: .created) ?? .distantPast
        name        = try c.decode(String.self,          forKey: .name)
        category    = try c.decode(String.self,          forKey: .category)
        projectType = try c.decode(ProjectType.self,     forKey: .projectType)
        state       = try c.decode(ProjectState.self,    forKey: .state)
        log         = try c.decode([LogEntry].self,      forKey: .log)
        start       = try c.decodeIfPresent(Date.self,   forKey: .start)
        end         = try c.decodeIfPresent(Date.self,   forKey: .end)
        modified    = try c.decode(Date.self,            forKey: .modified)
        folder      = try c.decodeIfPresent(String.self, forKey: .folder)
        notes       = try c.decode([Note].self,          forKey: .notes)
        touched     = try c.decode([Date].self,          forKey: .touched)
        latestReview = try c.decodeIfPresent(Date.self,  forKey: .latestReview)
        next        = try c.decodeIfPresent(Date.self,   forKey: .next)
        url         = try c.decodeIfPresent(String.self, forKey: .url)
        goal        = try c.decode(String.self,          forKey: .goal)
    }
}

// MARK: - Sort helpers for Table columns
// These give TableColumn a Comparable key path for optional/array fields.

extension Project {
    /// `String?` → sortable: projects without a folder sort before those with one.
    var folderOrEmpty: String    { folder ?? "" }
    /// `Date?`   → sortable: projects without a Next date sort last.
    var nextOrFuture:  Date      { next ?? .distantFuture }
    /// `[Date]`  → sortable: projects never touched sort first.
    var lastTouched:   Date      { touched.last ?? .distantPast }
    /// `[Note]`  → sortable: projects without notes sort first.
    var lastNoteText:  String    { notes.last?.text ?? "" }
    /// `String?` → sortable: projects without a URL sort before those with one.
    var urlOrEmpty:    String    { url ?? "" }
}
