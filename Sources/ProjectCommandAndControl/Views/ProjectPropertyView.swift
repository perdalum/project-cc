import SwiftUI
import AppKit

struct ProjectPropertyView: View {
    @EnvironmentObject var store: ProjectStore

    @State private var project: Project
    @State private var newNoteText    = ""
    @State private var showGoalEditor = false

    init(project: Project) {
        _project = State(initialValue: project)
    }

    var body: some View {
        Form {
            identitySection
            datesSection
            linksSection
            goalSection
            notesSection
            logSection
            touchedSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 640)
        .navigationTitle(project.name)
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorView(goal: $project.goal)
        }
        // Auto-save: every field change is written to the store immediately.
        .onChange(of: project) { _, newValue in
            store.update(newValue)
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section("Identity") {
            TextField("Name", text: $project.name)
            TextField("Category", text: $project.category)
            Picker("Type", selection: $project.projectType) {
                ForEach(ProjectType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            Picker("State", selection: $project.state) {
                ForEach(ProjectState.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
        }
    }

    private var datesSection: some View {
        Section("Dates") {
            optionalDatePicker("Start",         binding: optionalDate(for: \.start))
            optionalDatePicker("End",           binding: optionalDate(for: \.end))
            optionalDatePicker("Latest Review", binding: optionalDate(for: \.latestReview))
            optionalDatePicker("Next",          binding: optionalDate(for: \.next))
            LabeledContent("Modified") {
                Text(project.modified.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Created") {
                Text(project.created.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var linksSection: some View {
        Section("Links") {
            LabeledContent("Folder") {
                HStack {
                    if let folder = project.folder {
                        Text(folder)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                    }
                    Button(project.folder == nil ? "Choose…" : "Change…") {
                        if let path = pickFolder() { project.folder = path }
                    }
                    if project.folder != nil {
                        Button("Remove") { project.folder = nil }
                            .foregroundStyle(.red)
                    }
                }
            }
            TextField("URL", text: optionalString(for: \.url))
        }
    }

    private var goalSection: some View {
        Section("Goal") {
            Button("Edit goal…") { showGoalEditor = true }
            if !project.goal.isEmpty {
                Text(project.goal)
                    .lineLimit(4)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes (\(project.notes.count))") {
            ForEach(project.notes.reversed()) { note in
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(note.text)
                }
            }
            HStack {
                TextField("Add note…", text: $newNoteText)
                Button("Add") {
                    project.notes.append(Note(text: newNoteText))
                    newNoteText = ""
                }
                .disabled(newNoteText.isEmpty)
            }
        }
    }

    private var logSection: some View {
        Section("State Log") {
            if project.log.isEmpty {
                Text("No state changes recorded.").foregroundStyle(.secondary)
            } else {
                ForEach(project.log.reversed()) { entry in
                    HStack(spacing: 6) {
                        Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(entry.oldState.rawValue) → \(entry.newState.rawValue)")
                        if !entry.comment.isEmpty {
                            Text("(\(entry.comment))").foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var touchedSection: some View {
        Section("Touched (\(project.touched.count))") {
            Button("Touch now") {
                project.touched.append(Date())
            }
            if let last = project.touched.last {
                LabeledContent("Last touch") {
                    Text(last.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Binding helpers

    private func optionalDatePicker(_ label: String, binding: Binding<Date>) -> some View {
        DatePicker(label, selection: binding, displayedComponents: [.date, .hourAndMinute])
    }

    private func optionalDate(for keyPath: WritableKeyPath<Project, Date?>) -> Binding<Date> {
        Binding(
            get: { project[keyPath: keyPath] ?? Date() },
            set: { project[keyPath: keyPath] = $0 }
        )
    }

    private func optionalString(for keyPath: WritableKeyPath<Project, String?>) -> Binding<String> {
        Binding(
            get: { project[keyPath: keyPath] ?? "" },
            set: { project[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Goal editor window

struct GoalEditorView: View {
    @Binding var goal: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            TextEditor(text: $goal)
                .font(.body)
                .padding()
            Divider()
            Button("Done") { dismiss() }
                .keyboardShortcut(.return, modifiers: .command)
                .padding(12)
        }
        .frame(minWidth: 420, minHeight: 280)
    }
}

// MARK: - Folder picker

/// Shows a macOS open-panel restricted to directories. Returns the chosen path, or nil if cancelled.
func pickFolder() -> String? {
    let panel = NSOpenPanel()
    panel.canChooseFiles          = false
    panel.canChooseDirectories    = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories    = true
    panel.title                   = "Select Project Folder"
    guard panel.runModal() == .OK else { return nil }
    return panel.url?.path
}
