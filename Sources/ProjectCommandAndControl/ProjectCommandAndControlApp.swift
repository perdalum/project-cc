import SwiftUI

@main
struct ProjectCommandAndControlApp: App {
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 1200, height: 720)

        // One window per project ID; re-opening an already-open project brings it to front.
        WindowGroup(id: "project-detail", for: Project.ID.self) { $projectID in
            if let id = projectID,
               let project = store.projects.first(where: { $0.id == id }) {
                ProjectPropertyView(project: project)
                    .environmentObject(store)
            }
        }
        .defaultSize(width: 560, height: 700)
    }
}
