import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var store: ProjectStore

    @State private var filterText = ""
    @State private var filterState: StateFilter = .all
    @State private var timeRange: OverviewTimeRange = .week
    @State private var highlightedProjectID: Project.ID? = nil

    private var filteredProjects: [Project] {
        ProjectFilterSupport.filteredProjects(
            store.projects,
            filterText: filterText,
            stateFilter: filterState
        )
    }

    private var overviewData: OverviewData {
        OverviewAggregation.makeData(projects: filteredProjects, range: timeRange)
    }

    var body: some View {
        VStack(spacing: 0) {
            controlsBar
            Divider()

            if filteredProjects.isEmpty {
                ContentUnavailableView(
                    "No matching projects",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Adjust the filter text or state filter to see project activity.")
                )
            } else if !overviewData.hasActivity {
                ContentUnavailableView(
                    "No activity in range",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No touch events were recorded for the current filters in the selected time range.")
                )
            } else {
                chartSection(data: overviewData)
            }
        }
        .navigationTitle("Overview")
        .onChange(of: filterText) { _, _ in clearStaleHighlight() }
        .onChange(of: filterState) { _, _ in clearStaleHighlight() }
        .onChange(of: timeRange) { _, _ in clearStaleHighlight() }
        .onChange(of: store.projects) { _, _ in clearStaleHighlight() }
    }

    private var controlsBar: some View {
        VStack(spacing: 10) {
            Picker("Range", selection: $timeRange) {
                ForEach(OverviewTimeRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Filter name  ( -word = NOT,  word|word = OR )", text: $filterText)
                    .textFieldStyle(.plain)
                Divider().frame(height: 20)
                Picker("State", selection: $filterState) {
                    Text("All States").tag(StateFilter.all)
                    Divider()
                    ForEach(StateFilter.groups, id: \.self) { group in
                        Text(group.label)
                            .fontWeight(.semibold)
                            .tag(group)
                    }
                    Divider()
                    ForEach(ProjectState.allCases, id: \.self) { state in
                        Text(state.rawValue).tag(StateFilter.single(state))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
        }
        .padding()
        .background(.bar)
    }

    @ViewBuilder
    private func chartSection(data: OverviewData) -> some View {
        GeometryReader { geometry in
            let bucketWidth = bucketColumnWidth(for: timeRange)
            let chartWidth = max(geometry.size.width - 32, CGFloat(data.buckets.count) * bucketWidth)
            let heatmapHeight = max(260, CGFloat(data.rows.count) * 28)

            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 16) {
                    summaryHeader(
                        title: "Total Touches / \(timeRange.bucketLabel)",
                        subtitle: "\(filteredProjects.count) project\(filteredProjects.count == 1 ? "" : "s")"
                    )
                    summaryChart(
                        width: chartWidth,
                        data: data,
                        value: \.touchCount,
                        maxValue: max(data.maxTouchCount, 1),
                        color: Color.accentColor,
                        showCounts: true
                    )

                    summaryHeader(
                        title: "Project Activity",
                        subtitle: highlightedProjectName(in: data) ?? "Click a lane to highlight it"
                    )
                    heatmapChart(width: chartWidth, height: heatmapHeight, data: data)

                    summaryHeader(
                        title: "Context Switches / \(timeRange.bucketLabel)",
                        subtitle: "Counts project-to-project switches in chronological touch order"
                    )
                    summaryChart(
                        width: chartWidth,
                        data: data,
                        value: \.switchCount,
                        maxValue: max(data.maxSwitchCount, 1),
                        color: Color.orange,
                        showCounts: false
                    )
                }
                .padding()
            }
        }
    }

    private func summaryHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryChart(
        width: CGFloat,
        data: OverviewData,
        value: KeyPath<OverviewSummaryBucket, Int>,
        maxValue: Int,
        color: Color,
        showCounts: Bool
    ) -> some View {
        Chart(data.summaries) { bucket in
            BarMark(
                x: .value("Bucket", bucket.bucketIndex),
                y: .value("Value", bucket[keyPath: value])
            )
            .foregroundStyle(color.gradient)
            .annotation(position: .top, spacing: 3) {
                if showCounts || bucket[keyPath: value] > 0 {
                    Text("\(bucket[keyPath: value])")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXScale(domain: -0.5 ... Double(max(data.buckets.count, 1)) - 0.5)
        .chartYScale(domain: 0 ... Double(maxValue))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(width: width, height: 110)
    }

    private func heatmapChart(width: CGFloat, height: CGFloat, data: OverviewData) -> some View {
        Chart(data.cells) { cell in
            RectangleMark(
                xStart: .value("Bucket Start", Double(cell.bucketIndex)),
                xEnd: .value("Bucket End", Double(cell.bucketIndex + 1)),
                yStart: .value("Row Start", Double(cell.rowIndex)),
                yEnd: .value("Row End", Double(cell.rowIndex + 1))
            )
            .foregroundStyle(cellColor(for: cell, data: data))
            .cornerRadius(3)
        }
        .chartXScale(domain: 0 ... Double(max(data.buckets.count, 1)))
        .chartYScale(domain: 0 ... Double(max(data.rows.count, 1)))
        .chartXAxis {
            AxisMarks(values: xAxisValues(for: data)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let index = value.as(Double.self).map({ Int(floor($0)) }),
                       let bucket = data.buckets.first(where: { $0.index == index }) {
                        Text(bucket.label)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: data.rows.map { Double($0.rowIndex) + 0.5 }) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(anchor: .trailing) {
                    if let rowIndex = value.as(Double.self).map({ Int(floor($0)) }),
                       let row = data.rows.first(where: { $0.rowIndex == rowIndex }) {
                        Text(row.name)
                            .lineLimit(1)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { innerGeometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { tap in
                                handleTap(tap.location, proxy: proxy, geometry: innerGeometry, data: data)
                            }
                    )
            }
        }
        .frame(width: width, height: height)
    }

    private func cellColor(for cell: OverviewHeatmapCell, data: OverviewData) -> Color {
        let maxCount = max(data.maxCellCount, 1)
        let normalized = Double(cell.count) / Double(maxCount)
        let isHighlighted = highlightedProjectID == nil || highlightedProjectID == cell.projectID

        if cell.count == 0 {
            return isHighlighted ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04)
        }

        let baseOpacity = 0.18 + (normalized * 0.72)
        let opacity = isHighlighted ? baseOpacity : baseOpacity * 0.35
        return Color.accentColor.opacity(opacity)
    }

    private func xAxisValues(for data: OverviewData) -> [Double] {
        guard !data.buckets.isEmpty else { return [] }
        let axisStride: Int
        switch data.buckets.count {
        case 0...8: axisStride = 1
        case 9...18: axisStride = 2
        case 19...40: axisStride = 4
        default: axisStride = 6
        }

        var values = Swift.stride(from: 0, to: data.buckets.count, by: axisStride).map { Double($0) + 0.5 }
        if let lastIndex = data.buckets.last?.index {
            let centeredLast = Double(lastIndex) + 0.5
            if values.last != centeredLast {
                values.append(centeredLast)
            }
        }
        return values
    }

    private func handleTap(
        _ location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        data: OverviewData
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        let point = CGPoint(x: location.x - plotFrame.origin.x, y: location.y - plotFrame.origin.y)

        guard point.x >= 0,
              point.y >= 0,
              point.x <= plotFrame.size.width,
              point.y <= plotFrame.size.height,
              let bucketValue = proxy.value(atX: point.x, as: Double.self),
              let rowValue = proxy.value(atY: point.y, as: Double.self) else {
            return
        }

        let bucketIndex = min(max(Int(floor(bucketValue)), 0), max(data.buckets.count - 1, 0))
        let rowIndex = min(max(Int(floor(rowValue)), 0), max(data.rows.count - 1, 0))

        guard let row = data.rows.first(where: { $0.rowIndex == rowIndex }),
              data.cells.contains(where: { $0.projectID == row.projectID && $0.bucketIndex == bucketIndex }) else {
            return
        }

        highlightedProjectID = highlightedProjectID == row.projectID ? nil : row.projectID
    }

    private func highlightedProjectName(in data: OverviewData) -> String? {
        guard let highlightedProjectID,
              let row = data.rows.first(where: { $0.projectID == highlightedProjectID }) else {
            return nil
        }
        return row.name
    }

    private func clearStaleHighlight() {
        guard let highlightedProjectID else { return }
        if !filteredProjects.contains(where: { $0.id == highlightedProjectID }) {
            self.highlightedProjectID = nil
        }
    }

    private func bucketColumnWidth(for range: OverviewTimeRange) -> CGFloat {
        switch range {
        case .day: return 42
        case .week: return 54
        case .month: return 36
        case .threeMonths, .sixMonths: return 44
        case .all: return 50
        }
    }
}
