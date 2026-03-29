import Foundation
import Testing
@testable import ProjectCommandAndControl

@Suite struct OverviewSupportTests {
    let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    @Test func nameFilterSupportsAndOrAndNot() {
        #expect(ProjectFilterSupport.nameMatches("alpha beta", name: "Alpha Beta Project"))
        #expect(!ProjectFilterSupport.nameMatches("alpha beta", name: "Alpha Only"))
        #expect(ProjectFilterSupport.nameMatches("alpha|gamma", name: "Gamma Project"))
        #expect(ProjectFilterSupport.nameMatches("alpha -beta", name: "Alpha Project"))
        #expect(!ProjectFilterSupport.nameMatches("alpha -beta", name: "Alpha Beta Project"))
    }

    @Test func groupedStateFilterMatchesConfiguredStates() {
        let filter = StateFilter.group("Done", [.rejected, .done])
        #expect(filter.matches(.done))
        #expect(filter.matches(.rejected))
        #expect(!filter.matches(.active))
    }

    @Test func weekRangeBuildsDailyBucketsAndTotals() throws {
        let now = try date("2026-03-29T12:00:00Z")
        let alpha = project(
            name: "Alpha",
            touches: [
                "2026-03-23T10:00:00Z",
                "2026-03-29T09:00:00Z",
                "2026-03-29T10:00:00Z"
            ]
        )
        let beta = project(
            name: "Beta",
            touches: [
                "2026-03-24T11:00:00Z",
                "2026-03-29T11:00:00Z"
            ]
        )

        let data = OverviewAggregation.makeData(
            projects: [alpha, beta],
            range: .week,
            now: now,
            calendar: calendar
        )

        #expect(data.buckets.count == 7)
        #expect(data.summaries.map(\.touchCount) == [1, 1, 0, 0, 0, 0, 3])

        let finalAlphaCell = try #require(data.cells.first {
            $0.projectID == alpha.id && $0.bucketIndex == 6
        })
        let finalBetaCell = try #require(data.cells.first {
            $0.projectID == beta.id && $0.bucketIndex == 6
        })

        #expect(finalAlphaCell.count == 2)
        #expect(finalBetaCell.count == 1)
    }

    @Test func dayRangeUsesHourlyBuckets() throws {
        let now = try date("2026-03-29T10:30:00Z")
        let alpha = project(
            name: "Alpha",
            touches: [
                "2026-03-29T09:05:00Z",
                "2026-03-29T10:10:00Z"
            ]
        )

        let data = OverviewAggregation.makeData(
            projects: [alpha],
            range: .day,
            now: now,
            calendar: calendar
        )

        #expect(data.buckets.count == 24)
        #expect(data.summaries.suffix(2).map(\.touchCount) == [1, 1])
    }

    @Test func switchCountTracksProjectChangesInChronologicalOrder() throws {
        let now = try date("2026-03-29T12:00:00Z")
        let alpha = project(
            name: "Alpha",
            touches: [
                "2026-03-29T09:00:00Z",
                "2026-03-29T10:00:00Z",
                "2026-03-29T12:00:00Z"
            ]
        )
        let beta = project(
            name: "Beta",
            touches: [
                "2026-03-29T11:00:00Z"
            ]
        )

        let data = OverviewAggregation.makeData(
            projects: [alpha, beta],
            range: .week,
            now: now,
            calendar: calendar
        )

        #expect(data.summaries.last?.touchCount == 4)
        #expect(data.summaries.last?.switchCount == 2)
    }

    private func project(name: String, touches: [String], state: ProjectState = .new) -> Project {
        var project = Project(name: name, state: state)
        project.touched = touches.compactMap { try? date($0) }.sorted()
        return project
    }

    private func date(_ string: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = formatter.date(from: string) else {
            throw DateParseError(rawValue: string)
        }
        return date
    }
}

private struct DateParseError: Error {
    let rawValue: String
}
