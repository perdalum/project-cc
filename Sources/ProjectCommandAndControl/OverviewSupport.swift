import Foundation

enum StateFilter: Hashable {
    case all
    case group(String, [ProjectState])
    case single(ProjectState)

    var label: String {
        switch self {
        case .all: return "All States"
        case .group(let label, _): return label
        case .single(let state): return state.rawValue
        }
    }

    func matches(_ state: ProjectState) -> Bool {
        switch self {
        case .all: return true
        case .group(_, let states): return states.contains(state)
        case .single(let selectedState): return state == selectedState
        }
    }

    static let groups: [StateFilter] = [
        .group("Init", [.new, .idea]),
        .group("Not Done", [.idea, .new, .active, .delegated, .waiting]),
        .group("Started", [.active, .delegated, .waiting]),
        .group("Done", [.rejected, .done]),
    ]
}

enum ProjectFilterSupport {
    static let defaultSortOrder = [KeyPathComparator(\Project.name)]

    static func matches(_ project: Project, filterText: String, stateFilter: StateFilter) -> Bool {
        stateFilter.matches(project.state) && nameMatches(filterText, name: project.name)
    }

    static func filteredProjects(
        _ projects: [Project],
        filterText: String,
        stateFilter: StateFilter,
        sortOrder: [KeyPathComparator<Project>] = defaultSortOrder
    ) -> [Project] {
        projects
            .filter { matches($0, filterText: filterText, stateFilter: stateFilter) }
            .sorted(using: sortOrder)
    }

    static func nameMatches(_ filterText: String, name: String) -> Bool {
        let trimmed = filterText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }

        let nameLower = name.lowercased()
        let orGroups = trimmed
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !orGroups.isEmpty else { return true }

        return orGroups.contains { group in
            group.components(separatedBy: " ")
                .filter { !$0.isEmpty }
                .allSatisfy { term in
                    let lower = term.lowercased()
                    if lower.hasPrefix("-"), lower.count > 1 {
                        return !nameLower.contains(String(lower.dropFirst()))
                    }
                    return nameLower.contains(lower)
                }
        }
    }
}

enum OverviewTimeRange: String, CaseIterable, Hashable, Identifiable {
    case day = "1d"
    case week = "1w"
    case month = "1m"
    case threeMonths = "3m"
    case sixMonths = "6m"
    case all = "all"

    var id: String { rawValue }

    var label: String { rawValue }

    var bucketLabel: String {
        switch self {
        case .day: return "Hour"
        case .week, .month: return "Day"
        case .threeMonths, .sixMonths: return "Week"
        case .all: return "Month"
        }
    }
}

struct OverviewBucket: Identifiable, Equatable {
    let index: Int
    let start: Date
    let end: Date
    let label: String

    var id: Int { index }
}

struct OverviewProjectRow: Identifiable, Equatable {
    let projectID: Project.ID
    let name: String
    let rowIndex: Int

    var id: Project.ID { projectID }
}

struct OverviewHeatmapCell: Identifiable, Equatable {
    let projectID: Project.ID
    let rowIndex: Int
    let bucketIndex: Int
    let bucketStart: Date
    let bucketLabel: String
    let count: Int

    var id: String { "\(projectID.uuidString)-\(bucketIndex)" }
}

struct OverviewSummaryBucket: Identifiable, Equatable {
    let bucketIndex: Int
    let bucketStart: Date
    let bucketLabel: String
    let touchCount: Int
    let switchCount: Int

    var id: Int { bucketIndex }
}

struct OverviewData: Equatable {
    let rows: [OverviewProjectRow]
    let buckets: [OverviewBucket]
    let cells: [OverviewHeatmapCell]
    let summaries: [OverviewSummaryBucket]
    let maxTouchCount: Int
    let maxSwitchCount: Int
    let maxCellCount: Int

    var hasActivity: Bool { summaries.contains { $0.touchCount > 0 } }
}

enum OverviewAggregation {
    static func makeData(
        projects: [Project],
        range: OverviewTimeRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> OverviewData {
        let buckets = makeBuckets(range: range, projects: projects, now: now, calendar: calendar)
        let rows = projects.enumerated().map { index, project in
            OverviewProjectRow(
                projectID: project.id,
                name: project.name,
                rowIndex: projects.count - 1 - index
            )
        }

        let allEvents = makeEvents(projects: projects)
        let maxBucketEnd = buckets.last?.end ?? now

        let eventsByBucket = Dictionary(grouping: allEvents.filter { event in
            guard let firstBucket = buckets.first else { return false }
            return event.date >= firstBucket.start && event.date < maxBucketEnd
        }) { event in
            bucketIndex(for: event.date, in: buckets)
        }

        let cells = rows.flatMap { row in
            buckets.map { bucket in
                let count = eventsByBucket[bucket.index, default: []]
                    .filter { $0.projectID == row.projectID }
                    .count
                return OverviewHeatmapCell(
                    projectID: row.projectID,
                    rowIndex: row.rowIndex,
                    bucketIndex: bucket.index,
                    bucketStart: bucket.start,
                    bucketLabel: bucket.label,
                    count: count
                )
            }
        }

        let summaries = buckets.map { bucket in
            let events = (eventsByBucket[bucket.index] ?? []).sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.projectID.uuidString < rhs.projectID.uuidString
            }
            return OverviewSummaryBucket(
                bucketIndex: bucket.index,
                bucketStart: bucket.start,
                bucketLabel: bucket.label,
                touchCount: events.count,
                switchCount: countSwitches(events)
            )
        }

        return OverviewData(
            rows: rows,
            buckets: buckets,
            cells: cells,
            summaries: summaries,
            maxTouchCount: summaries.map { $0.touchCount }.max() ?? 0,
            maxSwitchCount: summaries.map { $0.switchCount }.max() ?? 0,
            maxCellCount: cells.map { $0.count }.max() ?? 0
        )
    }

    private static func countSwitches(_ events: [Event]) -> Int {
        guard !events.isEmpty else { return 0 }
        var switches = 0
        var previousProjectID = events[0].projectID

        for event in events.dropFirst() {
            if event.projectID != previousProjectID {
                switches += 1
            }
            previousProjectID = event.projectID
        }

        return switches
    }

    private static func bucketIndex(for date: Date, in buckets: [OverviewBucket]) -> Int {
        guard let index = buckets.firstIndex(where: { date >= $0.start && date < $0.end }) else {
            return buckets.count - 1
        }
        return buckets[index].index
    }

    private static func makeEvents(projects: [Project]) -> [Event] {
        projects.flatMap { project in
            project.touched.map { Event(projectID: project.id, date: $0) }
        }
    }

    private static func makeBuckets(
        range: OverviewTimeRange,
        projects: [Project],
        now: Date,
        calendar: Calendar
    ) -> [OverviewBucket] {
        switch range {
        case .day:
            return makeFixedBuckets(
                count: 24,
                component: .hour,
                endAnchor: now,
                calendar: calendar,
                label: hourLabel
            )
        case .week:
            return makeFixedBuckets(
                count: 7,
                component: .day,
                endAnchor: now,
                calendar: calendar,
                label: dayLabel
            )
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return makeComponentBuckets(
                component: .day,
                start: calendar.startOfDay(for: start),
                endAnchor: now,
                calendar: calendar,
                label: dayLabel
            )
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return makeComponentBuckets(
                component: .weekOfYear,
                start: startOfWeek(for: start, calendar: calendar),
                endAnchor: now,
                calendar: calendar,
                label: weekLabel
            )
        case .sixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            return makeComponentBuckets(
                component: .weekOfYear,
                start: startOfWeek(for: start, calendar: calendar),
                endAnchor: now,
                calendar: calendar,
                label: weekLabel
            )
        case .all:
            let firstTouch = projects
                .flatMap(\.touched)
                .min()
                ?? now
            let start = startOfMonth(for: firstTouch, calendar: calendar)
            return makeComponentBuckets(
                component: .month,
                start: start,
                endAnchor: now,
                calendar: calendar,
                label: monthLabel
            )
        }
    }

    private static func makeFixedBuckets(
        count: Int,
        component: Calendar.Component,
        endAnchor: Date,
        calendar: Calendar,
        label: (Date) -> String
    ) -> [OverviewBucket] {
        let alignedEnd = aligned(date: endAnchor, component: component, calendar: calendar)
        let start = calendar.date(byAdding: component, value: -(count - 1), to: alignedEnd) ?? alignedEnd
        return makeComponentBuckets(
            component: component,
            start: start,
            endAnchor: endAnchor,
            calendar: calendar,
            label: label
        )
    }

    private static func makeComponentBuckets(
        component: Calendar.Component,
        start: Date,
        endAnchor: Date,
        calendar: Calendar,
        label: (Date) -> String
    ) -> [OverviewBucket] {
        let end = nextBoundary(after: endAnchor, component: component, calendar: calendar)
        var buckets: [OverviewBucket] = []
        var index = 0
        var cursor = aligned(date: start, component: component, calendar: calendar)

        while cursor < end {
            let next = calendar.date(byAdding: component, value: 1, to: cursor) ?? end
            buckets.append(
                OverviewBucket(index: index, start: cursor, end: next, label: label(cursor))
            )
            index += 1
            cursor = next
        }

        return buckets
    }

    private static func aligned(date: Date, component: Calendar.Component, calendar: Calendar) -> Date {
        switch component {
        case .hour:
            let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: parts) ?? date
        case .day:
            return calendar.startOfDay(for: date)
        case .weekOfYear:
            return startOfWeek(for: date, calendar: calendar)
        case .month:
            return startOfMonth(for: date, calendar: calendar)
        default:
            return date
        }
    }

    private static func nextBoundary(after date: Date, component: Calendar.Component, calendar: Calendar) -> Date {
        let start = aligned(date: date, component: component, calendar: calendar)
        return calendar.date(byAdding: component, value: 1, to: start) ?? date
    }

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private static func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour())
    }

    private static func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private static func weekLabel(_ date: Date) -> String {
        let week = Calendar.current.component(.weekOfYear, from: date)
        return "Wk \(String(format: "%02d", week))"
    }

    private static func monthLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year(.defaultDigits))
    }

    private struct Event: Equatable {
        let projectID: Project.ID
        let date: Date
    }
}
