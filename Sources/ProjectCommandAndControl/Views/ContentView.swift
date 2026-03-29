import SwiftUI

enum SidebarItem: String, CaseIterable, Hashable {
    case projects = "Projects"
    case overview = "Overview"
}

struct ContentView: View {
    @State private var selection: SidebarItem = .projects

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, id: \.self, selection: $selection) { item in
                Label(
                    item.rawValue,
                    systemImage: item == .projects ? "list.bullet" : "calendar.badge.clock"
                )
            }
            .navigationTitle("Command & Control")
        } detail: {
            switch selection {
            case .projects: ProjectListView()
            case .overview: OverviewView()
            }
        }
    }
}
