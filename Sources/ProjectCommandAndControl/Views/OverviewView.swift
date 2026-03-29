import SwiftUI

/// Placeholder — will become a calendar heat map of project activity.
struct OverviewView: View {
    @EnvironmentObject var store: ProjectStore

    var body: some View {
        ContentUnavailableView(
            "Overview coming soon",
            systemImage: "calendar.badge.clock",
            description: Text("A heat map of updates, state changes, and touches per project will appear here.")
        )
        .navigationTitle("Overview")
    }
}
