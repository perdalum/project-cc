import SwiftUI
import AppKit

// MARK: - Double-click monitor
//
// NSEvent local monitor sits outside SwiftUI's gesture system, so it never
// competes with NSTableView's own row-selection machinery.

// @unchecked Sendable: NSEvent monitors always call back on the main thread,
// so mutating @Published properties from those callbacks is safe.
private final class DoubleClickMonitor: ObservableObject, @unchecked Sendable {
    private var doubleClickToken: Any?
    private var keyToken: Any?

    /// Incremented each time ESC is pressed while the main window is key.
    @Published var escapeToggle = 0

    /// (Re-)registers a new double-click handler, replacing any previous one.
    func register(handler: @escaping @Sendable () -> Void) {
        if let t = doubleClickToken { NSEvent.removeMonitor(t) }
        doubleClickToken = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            if event.clickCount == 2, Self.isTableDoubleClick(event) { handler() }
            return event
        }
    }

    private static func isTableDoubleClick(_ event: NSEvent) -> Bool {
        guard let window = event.window,
              let contentView = window.contentView,
              let hitView = contentView.hitTest(event.locationInWindow)
        else {
            return false
        }

        var view: NSView? = hitView
        while let current = view {
            if current is NSTableView || current is NSTableRowView || current is NSTableCellView {
                return true
            }
            view = current.superview
        }
        return false
    }

    /// Registers a key-down monitor that fires whenever ESC is pressed.
    /// Returns the event unmodified so sheet/popover cancel buttons still work.
    func registerKeyHandler() {
        guard keyToken == nil else { return }
        keyToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {   // ESC
                DispatchQueue.main.async { self?.escapeToggle += 1 }
            }
            return event
        }
    }

    func unregister() {
        if let t = doubleClickToken { NSEvent.removeMonitor(t); doubleClickToken = nil }
        if let t = keyToken         { NSEvent.removeMonitor(t); keyToken = nil }
    }

    deinit { unregister() }
}

struct ProjectListView: View {
    @EnvironmentObject var store: ProjectStore

    @State private var filterText  = ""
    @State private var filterState: StateFilter = .all
    @State private var sortOrder = ProjectFilterSupport.defaultSortOrder
    @State private var columnCustomization = TableColumnCustomization<Project>()
    @State private var selectedIDs: Set<Project.ID> = []
    @StateObject private var clickMonitor = DoubleClickMonitor()
    @Environment(\.openWindow) private var openWindow

    // State-change flow (comment required for Delegated/Waiting/Rejected)
    @State private var pendingTargetIDs: Set<Project.ID> = []
    @State private var pendingState:     ProjectState?   = nil
    @State private var pendingComment    = ""
    @State private var showCommentAlert  = false

    // Context-menu "Set Next" for selection
    @State private var showNextForSelection = false

    // Inline Next editor
    @State private var editingNextID:  Project.ID? = nil
    @State private var draftNextDate:  Date        = Date()

    // Inline Note editor
    @State private var editingNoteID:  Project.ID? = nil
    @State private var draftNoteText:  String      = ""

    // Inline URL editor
    @State private var editingURLID:   Project.ID? = nil
    @State private var draftURL:       String      = ""

    // Keyboard / focus
    @FocusState private var filterFocused: Bool
    @State private var showNoteForSelection        = false
    @State private var showStatePickerForSelection = false

    // MARK: Derived data

    @State private var displayedProjects: [Project] = []

    private func refreshDisplay() {
        displayedProjects = ProjectFilterSupport.filteredProjects(
            store.projects,
            filterText: filterText,
            stateFilter: filterState,
            sortOrder: sortOrder
        )
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            projectTable
        }
        .navigationTitle("Projects")
        .onAppear {
            refreshDisplay()
            if let data = UserDefaults.standard.data(forKey: "projectListColumns"),
               let saved = try? JSONDecoder().decode(TableColumnCustomization<Project>.self, from: data) {
                columnCustomization = saved
            }
            refreshDoubleClickHandler()
            clickMonitor.registerKeyHandler()
        }
        .onDisappear { clickMonitor.unregister() }
        .onChange(of: store.projects)       { refreshDisplay() }
        .onChange(of: filterText)           { refreshDisplay() }
        .onChange(of: filterState)          { refreshDisplay() }
        .onChange(of: sortOrder)            { refreshDisplay() }
        .onChange(of: selectedIDs)          { _, _ in refreshDoubleClickHandler() }
        .onChange(of: clickMonitor.escapeToggle) { _, _ in filterFocused.toggle() }
        .onChange(of: columnCustomization)  { _, new in
            if let data = try? JSONEncoder().encode(new) {
                UserDefaults.standard.set(data, forKey: "projectListColumns")
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Add Project", systemImage: "plus") {
                    let project = Project(name: "New Project")
                    store.add(project)
                    selectedIDs = [project.id]
                    openWindow(id: "project-detail", value: project.id)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .alert("Comment required", isPresented: $showCommentAlert) {
            TextField("Who / why?", text: $pendingComment)
            Button("Confirm") {
                if let newState = pendingState {
                    pendingTargetIDs.forEach { store.changeState(of: $0, to: newState, comment: pendingComment) }
                }
                resetPending()
            }
            Button("Cancel", role: .cancel) { resetPending() }
        } message: {
            Text("A comment is required when moving to '\(pendingState?.rawValue ?? "")'.")
        }
        .sheet(isPresented: $showNextForSelection) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set Next (\(pendingTargetIDs.count) project\(pendingTargetIDs.count == 1 ? "" : "s"))")
                    .font(.headline)
                DatePicker("", selection: $draftNextDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                HStack {
                    Spacer()
                    Button("Cancel") { showNextForSelection = false }
                        .keyboardShortcut(.escape)
                    Button("Set") {
                        pendingTargetIDs.forEach { store.setNext(for: $0, to: draftNextDate) }
                        showNextForSelection = false
                    }
                    .keyboardShortcut(.return)
                }
            }
            .padding()
            .frame(minWidth: 280)
        }
        .sheet(isPresented: $showNoteForSelection) {
            NoteForSelectionSheet(count: pendingTargetIDs.count, text: $draftNoteText) {
                pendingTargetIDs.forEach { store.addNote(to: $0, text: draftNoteText) }
                draftNoteText = ""
                showNoteForSelection = false
            } onCancel: {
                draftNoteText = ""
                showNoteForSelection = false
            }
        }
        .sheet(isPresented: $showStatePickerForSelection) {
            StatePickerSheet(count: pendingTargetIDs.count) { state in
                showStatePickerForSelection = false
                initiateStateChange(for: pendingTargetIDs, to: state)
            } onCancel: {
                showStatePickerForSelection = false
            }
        }
        .overlay(alignment: .topLeading) { keyboardShortcuts }
    }

    // MARK: Subviews

    private var filterBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Filter name  ( -word = NOT,  word|word = OR )", text: $filterText)
                .textFieldStyle(.plain)
                .focused($filterFocused)
            Divider().frame(height: 20)
            Picker("State", selection: $filterState) {
                Text("All States").tag(StateFilter.all)
                Divider()
                ForEach(StateFilter.groups, id: \.self) { g in
                    Text(g.label)
                        .fontWeight(.semibold)
                        .tag(g)
                }
                Divider()
                ForEach(ProjectState.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(StateFilter.single(s))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var projectTable: some View {
        Table(displayedProjects, selection: $selectedIDs, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {

            // Folder icon — open folder if set; otherwise prompt to choose one
            TableColumn("Folder", value: \.folderOrEmpty) { p in
                Button {
                    if p.folder != nil {
                        openFolder(p)
                    } else if let path = pickFolder() {
                        store.setFolder(for: p.id, to: path)
                    }
                } label: {
                    Image(systemName: p.folder == nil ? "folder" : "folder.fill")
                        .foregroundStyle(p.folder == nil ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
            }
            .width(min: 28, ideal: 28, max: 28)
            .customizationID("folder")

            // Terminal — only active when a folder is set
            TableColumn("Terminal", value: \.folderOrEmpty) { p in
                Button {
                    openTerminal(p)
                } label: {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(p.folder == nil ? Color.secondary : Color.primary)
                }
                .buttonStyle(.plain)
                .disabled(p.folder == nil)
            }
            .width(min: 28, ideal: 28, max: 28)
            .customizationID("terminal")

            // URL — open in browser if set; otherwise prompt to enter one
            TableColumn("URL", value: \.urlOrEmpty) { p in
                Button {
                    if let urlString = p.url, let url = URL(string: urlString) {
                        NSWorkspace.shared.open(url)
                    } else {
                        editingURLID = p.id
                        draftURL     = ""
                    }
                } label: {
                    urlIcon(for: p)
                }
                .buttonStyle(.plain)
                .popover(isPresented: Binding(
                    get: { editingURLID == p.id },
                    set: { if !$0 { editingURLID = nil } }
                )) {
                    URLEditor(text: $draftURL) {
                        store.setURL(for: p.id, to: draftURL.isEmpty ? nil : draftURL)
                        editingURLID = nil
                        draftURL     = ""
                    }
                }
            }
            .width(min: 28, ideal: 28, max: 28)
            .customizationID("url")

            TableColumn("Name", value: \.name) { p in
                let nameColor: Color = selectedIDs.contains(p.id) ? .white : .primary
                Text(p.name)
                    .foregroundStyle(nameColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .customizationID("name")

            TableColumn("State", value: \.state) { p in
                Menu(p.state.rawValue) {
                    ForEach(ProjectState.allCases, id: \.self) { s in
                        Button(s.rawValue) { initiateStateChange(for: p, to: s) }
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            .width(min: 80, ideal: 100, max: 120)
            .customizationID("state")

            // Click → date-time popover
            TableColumn("Next", value: \.nextOrFuture) { p in
                Button {
                    editingNextID = p.id
                    draftNextDate = p.next ?? Date()
                } label: {
                    nextLabel(for: p)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(p.next == nil ? .tertiary : .primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .background(nextBackground(for: p.next))
                .popover(isPresented: Binding(
                    get: { editingNextID == p.id },
                    set: { if !$0 { editingNextID = nil } }
                )) {
                    NextEditor(date: $draftNextDate) {
                        store.setNext(for: p.id, to: draftNextDate)
                        editingNextID = nil
                    } onClear: {
                        store.setNext(for: p.id, to: nil)
                        editingNextID = nil
                    }
                }
            }
            .width(min: 120, ideal: 150)
            .customizationID("next")

            // Click → appends a touch; displays latest datetime
            TableColumn("Touched", value: \.lastTouched) { p in
                Button {
                    store.touch(id: p.id)
                } label: {
                    touchedLabel(for: p)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .width(min: 120, ideal: 150)
            .customizationID("touched")

            // Click → note text popover; displays latest note
            TableColumn("Note", value: \.lastNoteText) { p in
                Button(p.notes.last?.text ?? "—") {
                    editingNoteID = p.id
                    draftNoteText = ""
                }
                .buttonStyle(.plain)
                .foregroundStyle(p.notes.isEmpty ? .tertiary : .primary)
                .lineLimit(1)
                .popover(isPresented: Binding(
                    get: { editingNoteID == p.id },
                    set: { if !$0 { editingNoteID = nil } }
                )) {
                    NoteEditor(text: $draftNoteText) {
                        store.addNote(to: p.id, text: draftNoteText)
                        editingNoteID = nil
                        draftNoteText = ""
                    }
                }
            }
            .customizationID("note")
        }
        .contextMenu(forSelectionType: Project.ID.self) { ids in
            selectionContextMenu(for: ids)
        }
    }

    // MARK: Actions

    private func refreshDoubleClickHandler() {
        let ids    = selectedIDs
        let action = openWindow
        clickMonitor.register {
            for id in ids { action(id: "project-detail", value: id) }
        }
    }

    private func initiateStateChange(for project: Project, to newState: ProjectState) {
        initiateStateChange(for: [project.id], to: newState)
    }

    private func initiateStateChange(for ids: Set<Project.ID>, to newState: ProjectState) {
        if newState.requiresComment {
            pendingTargetIDs = ids
            pendingState     = newState
            showCommentAlert = true
        } else {
            ids.forEach { store.changeState(of: $0, to: newState) }
        }
    }

    @ViewBuilder
    private func selectionContextMenu(for ids: Set<Project.ID>) -> some View {
        if !ids.isEmpty {
            Button("Touch") { ids.forEach { store.touch(id: $0) } }
            Button("Set Next…") {
                pendingTargetIDs     = ids
                draftNextDate        = Date()
                showNextForSelection = true
            }
            Button("Clear Next") { ids.forEach { store.setNext(for: $0, to: nil) } }
            Menu("Set State") {
                ForEach(ProjectState.allCases, id: \.self) { state in
                    Button(state.rawValue) { initiateStateChange(for: ids, to: state) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { ids.forEach { store.delete(id: $0) } }
        }
    }

    private func urlIcon(for project: Project) -> some View {
        let icon  = project.url == nil ? "safari" : "safari.fill"
        let color = project.url == nil ? Color.secondary : Color.accentColor
        return Image(systemName: icon).foregroundStyle(color)
    }

    @ViewBuilder
    private func nextLabel(for project: Project) -> some View {
        if let d = project.next { adaptiveDateLabel(for: d) } else { Text("—") }
    }

    @ViewBuilder
    private func touchedLabel(for project: Project) -> some View {
        if let d = project.touched.last { adaptiveDateLabel(for: d) } else { Text("") }
    }

    // MARK: Adaptive date formatting (Finder-style)
    // Tries formats longest → shortest; ViewThatFits picks the first one that fits the column width.

    @ViewBuilder
    private func adaptiveDateLabel(for date: Date) -> some View {
        let cal  = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date) {
            ViewThatFits(in: .horizontal) {
                Text("Today at \(time)")
                Text("Today, \(time)")
                Text(time)
            }
            .lineLimit(1)
        } else if cal.isDateInYesterday(date) {
            ViewThatFits(in: .horizontal) {
                Text("Yesterday at \(time)")
                Text("Yesterday")
            }
            .lineLimit(1)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                Text(date.formatted(date: .abbreviated, time: .omitted))
                Text(date.formatted(date: .numeric,     time: .omitted))
                Text(date.formatted(.dateTime.month(.twoDigits).day()))
            }
            .lineLimit(1)
        }
    }

    private func nextBackground(for date: Date?) -> Color {
        guard let date else { return .clear }
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(date)             { return Color.green.opacity(0.15) }
        if date < now                          { return Color.red.opacity(0.15) }
        if date < now.addingTimeInterval(3 * 24 * 3600) { return Color.orange.opacity(0.15) }
        return .clear
    }

    private func openURL(_ project: Project) {
        guard let urlString = project.url, let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openFolder(_ project: Project) {
        guard let path = project.folder else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func openTerminal(_ project: Project) {
        guard let path = project.folder else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments     = ["-a", "Terminal", path]
        try? process.run()
    }

    private func resetPending() {
        pendingTargetIDs = []
        pendingState     = nil
        pendingComment   = ""
    }

    private func openSelectedProjects() {
        for id in selectedIDs { openWindow(id: "project-detail", value: id) }
    }

    /// Zero-size invisible buttons whose sole purpose is registering keyboard shortcuts.
    private var keyboardShortcuts: some View {
        HStack(spacing: 0) {
            // Return — open property view for selected rows (disabled while filter is focused)
            Button("") { openSelectedProjects() }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(selectedIDs.isEmpty || filterFocused)
            // Cmd+F — focus filter bar
            Button("") { filterFocused = true }
                .keyboardShortcut("f", modifiers: .command)
            // Cmd+T — touch selected
            Button("") { selectedIDs.forEach { store.touch(id: $0) } }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(selectedIDs.isEmpty)
            // Cmd+M — add note to selected
            Button("") {
                pendingTargetIDs = selectedIDs
                showNoteForSelection = true
            }
            .keyboardShortcut("m", modifiers: .command)
            .disabled(selectedIDs.isEmpty)
            // Cmd+D — set state for selected
            Button("") {
                pendingTargetIDs = selectedIDs
                showStatePickerForSelection = true
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(selectedIDs.isEmpty)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
    }
}

// MARK: - Inline popover editors

private struct NextEditor: View {
    @Binding var date: Date
    let onSet:   () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set Next").font(.headline)
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
            HStack {
                Button("Clear") { onClear() }
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Set") { onSet() }
                    .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(minWidth: 260)
    }
}

private struct NoteEditor: View {
    @Binding var text: String
    let onAdd: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add note").font(.headline)
            TextField("Note", text: $text)
                .focused($focused)
                .onSubmit { if !text.isEmpty { onAdd() } }
            HStack {
                Spacer()
                Button("Add") { onAdd() }
                    .keyboardShortcut(.return)
                    .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 260)
        .onAppear { focused = true }
    }
}

private struct URLEditor: View {
    @Binding var text: String
    let onSet: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set URL").font(.headline)
            TextField("https://", text: $text)
                .focused($focused)
                .onSubmit { if !text.isEmpty { onSet() } }
            HStack {
                Spacer()
                Button("Set") { onSet() }
                    .keyboardShortcut(.return)
                    .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 300)
        .onAppear { focused = true }
    }
}

private struct NoteForSelectionSheet: View {
    let count: Int
    @Binding var text: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Note\(count > 1 ? " (\(count) projects)" : "")").font(.headline)
            TextField("Note…", text: $text)
                .focused($focused)
                .onSubmit { if !text.isEmpty { onAdd() } }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Button("Add", action: onAdd)
                    .keyboardShortcut(.return)
                    .disabled(text.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 280)
        .onAppear { focused = true }
    }
}

private struct StatePickerSheet: View {
    let count: Int
    let onSelect: (ProjectState) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Set State\(count > 1 ? " (\(count) projects)" : "")").font(.headline)
            Divider()
            ForEach(ProjectState.allCases, id: \.self) { state in
                Button(state.rawValue) { onSelect(state) }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
            }
        }
        .padding()
        .frame(minWidth: 200)
    }
}
