//
//  ReadingCalendarHeatmap.swift
//  BookStride
//
//  GitHub-contribution-style annual reading consistency calendar for iPadOS.
//  Includes year navigation, month headers, weekday labels, accessible readout,
//  future date distinction, and day inspection linked to sessions and journal notes.
//

import SwiftUI

public struct ReadingCalendarHeatmap: View {
    public var sessions: [ReadingSessionDTO]
    public var books: [BookDTO]
    public var journalEntries: [JournalEntryDTO]
    public var dailyGoalMinutes: Int
    
    @State private var selectedYear: Int
    @State private var selectedPoint: HeatmapDayPoint?
    
    private let calendar = Calendar.current
    private let dayRowLabels = ["", "Mon", "", "Wed", "", "Fri", ""]
    
    public init(
        sessions: [ReadingSessionDTO],
        books: [BookDTO] = [],
        journalEntries: [JournalEntryDTO] = [],
        dailyGoalMinutes: Int = 30
    ) {
        self.sessions = sessions
        self.books = books
        self.journalEntries = journalEntries
        self.dailyGoalMinutes = dailyGoalMinutes
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }
    
    // Fallback initializer for backwards compatibility
    public init(points: [HeatmapDayPoint]) {
        self.sessions = []
        self.books = []
        self.journalEntries = []
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
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous Year")
                    
                    Text(String(format: "%d", selectedYear))
                        .font(.system(.subheadline, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                        .frame(minWidth: 48)
                    
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
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next Year")
                }
            }
            
            // Heatmap Centered/Scrollable Grid
            ViewThatFits(in: .horizontal) {
                HStack {
                    Spacer(minLength: 0)
                    calendarGridView(grid: grid)
                    Spacer(minLength: 0)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    calendarGridView(grid: grid)
                }
            }
            
            // Legend Row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(0))
                        .frame(width: 11, height: 11)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(1))
                        .frame(width: 11, height: 11)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(2))
                        .frame(width: 11, height: 11)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(3))
                        .frame(width: 11, height: 11)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(4))
                        .frame(width: 11, height: 11)
                    
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
    private func calendarGridView(grid: YearlyGridData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Month Headers Row
            HStack(alignment: .bottom, spacing: 3) {
                Color.clear.frame(width: 24, height: 14) // weekday label offset
                
                ForEach(0..<grid.weekColumns.count, id: \.self) { wIndex in
                    if let header = grid.monthHeaders.first(where: { $0.weekIndex == wIndex }) {
                        Text(header.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: 14, alignment: .leading)
                    } else {
                        Color.clear.frame(width: 14, height: 14)
                    }
                }
            }
            
            // Day Rows (Sun..Sat)
            HStack(alignment: .top, spacing: 3) {
                // Weekday labels column
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        Text(dayRowLabels[row])
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                            .frame(width: 24, height: 14, alignment: .trailing)
                    }
                }
                
                // Weeks Grid
                ForEach(0..<grid.weekColumns.count, id: \.self) { wIndex in
                    let week = grid.weekColumns[wIndex]
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { rIndex in
                            if let point = week[rIndex] {
                                dayCell(point: point)
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.clear)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func dayCell(point: HeatmapDayPoint) -> some View {
        let isSelected = selectedPoint?.id == point.id
        
        Button {
            selectedPoint = point
        } label: {
            ZStack {
                if point.isFuture {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(BookStrideTheme.borderLight.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.clear))
                        .frame(width: 14, height: 14)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(intensityColor(point.intensity))
                        .frame(width: 14, height: 14)
                }
                
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
        .accessibilityLabel(
            point.isFuture
                ? "\(Formatters.formatDate(point.date, style: .fullDate)): Future date. No reading recorded."
                : "\(Formatters.formatDate(point.date, style: .fullDate)): \(point.minutes) minutes read. \(point.metGoal ? "Daily goal achieved." : (point.minutes > 0 ? "Goal not reached." : "No reading recorded."))"
        )
        .accessibilityHint("Double tap to inspect details.")
    }
    
    @ViewBuilder
    private func dayDetailCard(point: HeatmapDayPoint) -> some View {
        let daySessions = sessions.filter { s in
            calendar.isDate(s.startedAt, inSameDayAs: point.date)
        }
        let dayEntries = journalEntries.filter { j in
            calendar.isDate(j.createdAt, inSameDayAs: point.date)
        }
        
        VStack(alignment: .leading, spacing: 12) {
            // Summary Header Row
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(point.isFuture ? BookStrideTheme.cardLight : intensityColor(point.intensity))
                        .frame(width: 40, height: 40)
                        .overlay(
                            point.isFuture
                                ? Circle().strokeBorder(BookStrideTheme.borderLight, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                : nil
                        )
                    
                    Image(systemName: point.isFuture ? "calendar.badge.clock" : (point.metGoal ? "checkmark" : (point.minutes > 0 ? "book.fill" : "moon.stars")))
                        .font(.callout.weight(.bold))
                        .foregroundColor(point.intensity >= 2 && !point.isFuture ? .white : BookStrideTheme.deepCharcoal)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(Formatters.formatDate(point.date, style: .fullDate))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    
                    if point.isFuture {
                        Text("Future date • No reading activity recorded yet")
                            .font(.caption)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    } else if point.minutes > 0 {
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
                
                if !point.isFuture && point.minutes > 0 {
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
            
            // Detailed Sessions List for this day
            if !daySessions.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sessions on this day")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    
                    ForEach(daySessions) { s in
                        let book = books.first(where: { $0.id == s.bookId })
                        let dotColor = BookStrideTheme.bookCoverColors[book?.coverColorHex ?? "forest"] ?? BookStrideTheme.forestGreen
                        HStack(spacing: 10) {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book?.title ?? "Untitled Session")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                                
                                if let start = s.startPage, let end = s.endPage, end >= start {
                                    Text("Pages \(start)–\(end) (\(end - start + 1) pages)")
                                        .font(.caption2)
                                        .foregroundColor(BookStrideTheme.mutedSlate)
                                }
                            }
                            
                            Spacer()
                            
                            Text(Formatters.formatDuration(seconds: s.activeSeconds, style: .short))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(BookStrideTheme.deepCharcoal)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            // Detailed Journal Entries for this day
            if !dayEntries.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Journal entries on this day")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    
                    ForEach(dayEntries) { entry in
                        let book = books.first(where: { $0.id == entry.bookId })
                        HStack(spacing: 8) {
                            Text(entry.entryType.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(BookStrideTheme.forestGreen)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(BookStrideTheme.forestGreenLight.opacity(0.2))
                                .cornerRadius(4)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.content)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                                    .lineLimit(1)
                                
                                if let book = book {
                                    Text(book.title)
                                        .font(.caption2)
                                        .foregroundColor(BookStrideTheme.mutedSlate)
                                }
                            }
                            
                            Spacer()
                            
                            if let page = entry.pageNumber {
                                Text("p. \(page)")
                                    .font(.caption2)
                                    .foregroundColor(BookStrideTheme.mutedSlate)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
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
            return BookStrideTheme.borderLight
        case 1:
            return BookStrideTheme.forestGreenLight.opacity(0.40)
        case 2:
            return BookStrideTheme.forestGreenLight.opacity(0.70)
        case 3:
            return BookStrideTheme.forestGreen.opacity(0.85)
        case 4:
            return BookStrideTheme.forestGreen
        default:
            return BookStrideTheme.borderLight
        }
    }
}
