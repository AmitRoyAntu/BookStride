//
//  InsightsView.swift
//  BookStride
//
//  Rich analytics dashboard on iPad with Swift Charts, metrics, streaks, and habits.
//

import SwiftUI
import SwiftData

public struct InsightsView: View {
    @Query private var allSessions: [ReadingSession]
    @Query private var allBooks: [Book]
    @Query private var goals: [ReadingGoal]
    
    @State private var selectedFilter: TimeFilter = .last30Days
    @State private var showingFullSessionHistory: Bool = false
    
    public init() {}
    
    private var dailyGoalMinutes: Int {
        goals.first?.dailyMinutes ?? 30
    }
    
    // Map SwiftData entities to DTOs for calculation
    private var computedData: (
        summary: InsightsAnalyticsSummary,
        dailyPoints: [DailyReadingPoint],
        weeklyTrend: [WeeklyReadingPoint],
        monthlyActivity: [MonthlyReadingPoint],
        bookDistribution: [BookTimePoint],
        heatmapPoints: [HeatmapDayPoint]
    ) {
        let sessionDTOs = allSessions.map { s in
            ReadingSessionDTO(
                id: s.id,
                bookId: s.book?.id,
                startedAt: s.startedAt,
                endedAt: s.endedAt,
                status: s.statusRawValue,
                accumulatedActiveSeconds: s.accumulatedActiveSeconds,
                pausedDurationSeconds: s.pausedDurationSeconds,
                startPage: s.startPage,
                endPage: s.endPage,
                notes: s.notes
            )
        }
        
        let bookDTOs = allBooks.map { b in
            BookDTO(
                id: b.id,
                title: b.title,
                author: b.author,
                coverColorHex: b.coverColorHex,
                coverIcon: b.coverIcon,
                totalPages: b.totalPages,
                currentPage: b.currentPage,
                status: b.statusRawValue
            )
        }
        
        return ReadingStatisticsService.computeAnalytics(
            sessions: sessionDTOs,
            books: bookDTOs,
            filter: selectedFilter,
            dailyGoalMinutes: dailyGoalMinutes
        )
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Time Filter Picker & Logs Action
                ViewThatFits(in: .horizontal) {
                    HStack {
                        timeFilterPicker
                        Spacer()
                        sessionLogsButton
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        timeFilterPicker
                        sessionLogsButton
                    }
                }
                .padding(.horizontal, 24)
                
                // 1. Primary Metrics Grid
                LazyVGrid(columns: LayoutConstants.dashboardColumns, spacing: 16) {
                    MetricCard(
                        title: "Total Reading Time",
                        value: Formatters.formatDuration(seconds: computedData.summary.totalReadingSeconds, style: .full),
                        subtitle: "Filter: \(selectedFilter.rawValue)",
                        iconName: "clock.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "Reading Today",
                        value: Formatters.formatDuration(seconds: computedData.summary.readingSecondsToday, style: .short),
                        subtitle: "Goal: \(dailyGoalMinutes)m",
                        iconName: "sun.max.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "This Week",
                        value: Formatters.formatDuration(seconds: computedData.summary.readingSecondsThisWeek, style: .short),
                        subtitle: "Active local week",
                        iconName: "calendar.badge.clock",
                        accentColor: BookStrideTheme.forestGreenLight
                    )
                    
                    MetricCard(
                        title: "This Month",
                        value: Formatters.formatDuration(seconds: computedData.summary.readingSecondsThisMonth, style: .short),
                        subtitle: "Active local month",
                        iconName: "calendar",
                        accentColor: BookStrideTheme.forestGreenLight
                    )
                    
                    MetricCard(
                        title: "Current Streak",
                        value: "\(computedData.summary.currentStreak) Days",
                        subtitle: "Best: \(computedData.summary.longestStreak) days",
                        iconName: "flame.fill",
                        accentColor: BookStrideTheme.streakAmber
                    )
                    
                    MetricCard(
                        title: "Goal Completion Rate",
                        value: Formatters.formatPercentage(computedData.summary.goalCompletionRate),
                        subtitle: "Days meeting \(dailyGoalMinutes)m goal",
                        iconName: "target",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "Sessions Completed",
                        value: "\(computedData.summary.totalSessionsCount)",
                        subtitle: "Avg: \(Formatters.formatDuration(seconds: computedData.summary.averageSessionSeconds, style: .short)) / session",
                        iconName: "book.pages.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "Pages Turned",
                        value: "\(computedData.summary.totalPagesRead)",
                        subtitle: "\(computedData.summary.totalBooksFinishedCount) books finished",
                        iconName: "text.book.closed.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                }
                .padding(.horizontal, 24)
                
                // 2. Daily Reading Chart
                DailyReadingBarChart(
                    points: computedData.dailyPoints,
                    goalMinutes: Double(dailyGoalMinutes)
                )
                .padding(.horizontal, 24)
                
                // 3. Goal Consistency Breakdown
                GoalConsistencyCard(
                    summary: computedData.summary,
                    dailyPoints: computedData.dailyPoints,
                    dailyGoalMinutes: dailyGoalMinutes
                )
                .padding(.horizontal, 24)
                
                // 4. Side-by-side or stacked trends on iPad (responsive portrait/landscape)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        WeeklyTrendChart(points: computedData.weeklyTrend)
                        MonthlyActivityChart(points: computedData.monthlyActivity)
                    }
                    VStack(spacing: 20) {
                        WeeklyTrendChart(points: computedData.weeklyTrend)
                        MonthlyActivityChart(points: computedData.monthlyActivity)
                    }
                }
                .padding(.horizontal, 24)
                
                // 5. GitHub-style Reading Consistency Heatmap (Full Year with Year Nav)
                ReadingCalendarHeatmap(
                    sessions: allSessions.map { s in
                        ReadingSessionDTO(
                            id: s.id,
                            bookId: s.book?.id,
                            startedAt: s.startedAt,
                            endedAt: s.endedAt,
                            status: s.statusRawValue,
                            accumulatedActiveSeconds: s.accumulatedActiveSeconds,
                            pausedDurationSeconds: s.pausedDurationSeconds,
                            startPage: s.startPage,
                            endPage: s.endPage,
                            notes: s.notes
                        )
                    },
                    dailyGoalMinutes: dailyGoalMinutes
                )
                .padding(.horizontal, 24)
                
                // 6. Book Distribution Breakdown
                BookTimeDistributionChart(distribution: computedData.bookDistribution)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 20)
        }
        .BookStrideBackground()
        .navigationTitle("Insights")
    }
    
    private var timeFilterPicker: some View {
        Picker("Time Period", selection: $selectedFilter) {
            ForEach(TimeFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)
    }
    
    private var sessionLogsButton: some View {
        NavigationLink {
            SessionHistoryView()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "list.bullet.rectangle")
                Text("Session Logs")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.callout.weight(.medium))
            .foregroundColor(BookStrideTheme.forestGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(BookStrideTheme.cardLight)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

