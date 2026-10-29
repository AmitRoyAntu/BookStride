//
//  ReadingCalendarHeatmap.swift
//  BookStride
//
//  GitHub-contribution-style annual reading consistency calendar for iPadOS.
//  Includes year navigation, month headers, weekday labels, accessible readout, and day inspection.
//

import SwiftUI

public struct ReadingCalendarHeatmap: View {
    public var sessions: [ReadingSessionDTO]
    public var dailyGoalMinutes: Int
    
    @State private var selectedYear: Int
    @State private var selectedPoint: HeatmapDayPoint?
    
    private let calendar = Calendar.current
    private let dayRowLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    
    public init(sessions: [ReadingSessionDTO], dailyGoalMinutes: Int = 30) {
        self.sessions = sessions
        self.dailyGoalMinutes = dailyGoalMinutes
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }
    
    // Fallback initializer for backwards compatibility
    public init(points: [HeatmapDayPoint]) {
        self.sessions = []
        self.dailyGoalMinutes = 30
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }
    
    private struct YearlyGridData {
        let year: Int
        let points: [HeatmapDayPoint]
        let weekColumns: [[HeatmapDayPoint?]]
        let monthHeaders: [(name: String, weekIndex: Int)]
        let activeDaysCount: Int
    }
    
    private func buildGridData() -> YearlyGridData {
        let points = ReadingStatisticsService.computeYearlyHeatmap(
            sessions: sessions,
            year: selectedYear,
            dailyGoalMinutes: dailyGoalMinutes,
            calendar: calendar
        )
        
        guard let first = points.first else {
            return YearlyGridData(year: selectedYear, points: [], weekColumns: [], monthHeaders: [], activeDaysCount: 0)
        }
        
        let firstWeekday = calendar.component(.weekday, from: first.date) // 1 = Sunday
        var weeks: [[HeatmapDayPoint?]] = []
        var currentWeek: [HeatmapDayPoint?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for point in points {
            currentWeek.append(point)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        var headers: [(name: String, weekIndex: Int)] = []
        var lastSeenMonth = -1
        let df = DateFormatter()
        df.dateFormat = "MMM"
        
        for (wIndex, week) in weeks.enumerated() {
            if let firstValidDay = week.compactMap({ $0 }).first {
                let m = calendar.component(.month, from: firstValidDay.date)
                if m != lastSeenMonth {
                    headers.append((df.string(from: firstValidDay.date), wIndex))
                    lastSeenMonth = m
                }
            }
        }
        
        let activeDays = points.filter { $0.minutes > 0 }.count
        
        return YearlyGridData(
            year: selectedYear,
            points: points,
            weekColumns: weeks,
            monthHeaders: headers,
            activeDaysCount: activeDays
        )
    }
    
    public var body: some View {
        let grid = buildGridData()
        
        VStack(alignment: .leading, spacing: 16) {
            // Header: Title & Year Navigator
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading Consistency Calendar")
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("Daily habit consistency and goal momentum")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
                
                // Year Navigation Controls
                HStack(spacing: 8) {
                    Button {
                        selectedYear -= 1
                        selectedPoint = nil
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                            .padding(8)
                            .background(BookStrideTheme.cardLight)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(BookStrideTheme.borderLight, lineWidth: 1))
                    }
                    .accessibilityLabel("Previous Year")
                    
                    Text("\(String(format: "%d", selectedYear))")
                        .font(.headline.weight(.bold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                        .frame(minWidth: 55)
                    
                    Button {
                        selectedYear += 1
                        selectedPoint = nil
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                            .padding(8)
                            .background(BookStrideTheme.cardLight)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(BookStrideTheme.borderLight, lineWidth: 1))
                    }
                    .accessibilityLabel("Next Year")
                    
                    // Quick "Today" Jump Button
                    let currentRealYear = calendar.component(.year, from: Date())
                    if selectedYear != currentRealYear {
                        Button("This Year") {
                            selectedYear = currentRealYear
                            selectedPoint = nil
                        }
                        .font(.caption2.weight(.medium))
                        .foregroundColor(BookStrideTheme.forestGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(BookStrideTheme.forestGreen.opacity(0.12))
                        .cornerRadius(12)
                    }
                }
            }
            
            // GitHub Contribution Grid (horizontally scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    // Month Label Row
                    HStack(spacing: 0) {
                        Color.clear.frame(width: 28, height: 16) // Spacing for weekday column
                        
                        ZStack(alignment: .leading) {
                            Color.clear.frame(width: CGFloat(grid.weekColumns.count) * 17.0, height: 16)
                            
                            ForEach(grid.monthHeaders, id: \.weekIndex) { header in
                                Text(header.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(BookStrideTheme.mutedSlate)
                                    .offset(x: CGFloat(header.weekIndex) * 17.0)
                            }
                        }
                    }
                    
                    // Main Grid: Weekday labels on left, 53 week columns on right
                    HStack(alignment: .top, spacing: 6) {
                        // Weekday indicators (Mon, Wed, Fri)
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { row in
                                Text(dayRowLabels[row])
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(BookStrideTheme.mutedSlate)
                                    .frame(width: 22, height: 14, alignment: .trailing)
                            }
                        }
                        
                        // Week columns
                        HStack(spacing: 3) {
                            ForEach(0..<grid.weekColumns.count, id: \.self) { colIndex in
                                VStack(spacing: 3) {
                                    ForEach(0..<7, id: \.self) { rowIndex in
                                        if let point = grid.weekColumns[colIndex][rowIndex] {
                                            dayCell(point: point)
                                        } else {
                                            Color.clear.frame(width: 14, height: 14)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Legend & Selection readout
            HStack(alignment: .center) {
                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                    ForEach(0...4, id: \.self) { lvl in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(intensityColor(lvl))
                            .frame(width: 11, height: 11)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
                
                Text("\(grid.activeDaysCount) active days in \(String(format: "%d", selectedYear))")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            
            // Detailed Day Inspection Card
            if let selected = selectedPoint {
                dayDetailCard(point: selected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
    
    // MARK: - Subviews & Helpers
    
    @ViewBuilder
    private func dayCell(point: HeatmapDayPoint) -> some View {
        let isSelected = selectedPoint?.id == point.id
        
        Button {
            selectedPoint = point
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(intensityColor(point.intensity))
                    .frame(width: 14, height: 14)
                
                // Ring for today
                if point.isToday {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(BookStrideTheme.streakAmber, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                }
                
                // Active selection ring
                if isSelected {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(BookStrideTheme.deepCharcoal, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Formatters.formatDate(point.date, style: .fullDate)): \(point.minutes) minutes read. \(point.metGoal ? "Daily goal achieved." : (point.minutes > 0 ? "Goal not reached." : "No reading recorded."))")
        .accessibilityHint("Double tap to inspect details.")
    }
    
    @ViewBuilder
    private func dayDetailCard(point: HeatmapDayPoint) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(intensityColor(point.intensity))
                    .frame(width: 40, height: 40)
                
                Image(systemName: point.metGoal ? "checkmark" : (point.minutes > 0 ? "book.fill" : "moon.stars"))
                    .font(.callout.weight(.bold))
                    .foregroundColor(point.intensity >= 2 ? .white : BookStrideTheme.deepCharcoal)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.formatDate(point.date, style: .fullDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                
                if point.minutes > 0 {
                    Text("\(point.minutes) minutes read • \(point.sessionCount) \(point.sessionCount == 1 ? "session" : "sessions")")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                } else {
                    Text("No reading sessions logged on this day")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            
            Spacer()
            
            if point.minutes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: point.metGoal ? "target" : "hourglass")
                        .font(.caption2)
                    Text(point.metGoal ? "Goal Met (\(dailyGoalMinutes)m)" : "\(max(0, dailyGoalMinutes - point.minutes))m to goal")
                        .font(.caption2.weight(.bold))
                }
                .foregroundColor(point.metGoal ? BookStrideTheme.forestGreen : BookStrideTheme.streakAmber)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (point.metGoal ? BookStrideTheme.forestGreen : BookStrideTheme.streakAmber).opacity(0.12)
                )
                .cornerRadius(12)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(BookStrideTheme.cardLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(BookStrideTheme.borderLight, lineWidth: 1)
        )
    }
    
    private func intensityColor(_ level: Int) -> Color {
        switch level {
        case 0:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(white: 0.22, alpha: 1.0)
                    : UIColor(red: 234/255, green: 230/255, blue: 222/255, alpha: 1.0)
            })
        case 1:
            return BookStrideTheme.forestGreenLight.opacity(0.40)
        case 2:
            return BookStrideTheme.forestGreenLight.opacity(0.70)
        case 3:
            return BookStrideTheme.forestGreen.opacity(0.85)
        case 4:
            return BookStrideTheme.forestGreen
        default:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(white: 0.22, alpha: 1.0)
                    : UIColor(red: 234/255, green: 230/255, blue: 222/255, alpha: 1.0)
            })
        }
    }
}
