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
    @Query private var allJournalEntries: [JournalEntry]
    @Query private var goals: [ReadingGoal]
    
    @State private var selectedFilter: TimeFilter = .last30Days
    @State private var showingFullSessionHistory: Bool = false
    
    public init() {}
    
    private var dailyGoalMinutes: Int {
        goals.first?.dailyMinutes ?? 30
    }
    
    public var body: some View {
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
        
        let journalDTOs = allJournalEntries.map { j in
            JournalEntryDTO(
                id: j.id,
                bookId: j.book?.id,
                content: j.content,
                entryType: j.entryTypeRawValue,
                pageNumber: j.pageNumber,
                isFavorite: j.isFavorite,
                createdAt: j.createdAt,
                updatedAt: j.updatedAt
            )
        }
        
        let analytics = ReadingStatisticsService.computeAnalytics(
            sessions: sessionDTOs,
            books: bookDTOs,
            filter: selectedFilter,
            dailyGoalMinutes: dailyGoalMinutes
        )
        
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Time Filter Picker & Actions
                ViewThatFits(in: .horizontal) {
                    HStack {
                        timeFilterPicker
                        Spacer()
                        readingWrappedButton
                        sessionLogsButton
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        timeFilterPicker
                        HStack(spacing: 12) {
                            readingWrappedButton
                            sessionLogsButton
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Reading Wrapped Showcase Card
                readingWrappedShowcaseCard
                    .padding(.horizontal, 24)
                
                // 1. Primary Metrics Grid
                LazyVGrid(columns: LayoutConstants.dashboardColumns, spacing: 16) {
                    MetricCard(
                        title: "Total Reading Time",
                        value: Formatters.formatDuration(seconds: analytics.summary.totalReadingSeconds, style: .full),
                        subtitle: "Filter: \(selectedFilter.rawValue)",
                        iconName: "clock.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "Reading Today",
                        value: Formatters.formatDuration(seconds: analytics.summary.readingSecondsToday, style: .short),
                        subtitle: "Goal: \(dailyGoalMinutes)m",
                        iconName: "sun.max.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "This Week",
                        value: Formatters.formatDuration(seconds: analytics.summary.readingSecondsThisWeek, style: .short),
                        subtitle: "Active local week",
                        iconName: "calendar.badge.clock",
                        accentColor: BookStrideTheme.forestGreenLight
                    )
                    
                    MetricCard(
                        title: "This Month",
                        value: Formatters.formatDuration(seconds: analytics.summary.readingSecondsThisMonth, style: .short),
                        subtitle: "Active local month",
                        iconName: "calendar",
                        accentColor: BookStrideTheme.forestGreenLight
                    )
                    
                    MetricCard(
                        title: "Current Streak",
                        value: "\(analytics.summary.currentStreak) Days",
                        subtitle: "Best: \(analytics.summary.longestStreak) days",
                        iconName: "flame.fill",
                        accentColor: BookStrideTheme.streakAmber
                    )
                    
                    MetricCard(
                        title: "Goal Completion Rate",
                        value: Formatters.formatPercentage(analytics.summary.goalCompletionRate),
                        subtitle: "Days meeting \(dailyGoalMinutes)m goal",
                        iconName: "target",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "Sessions Completed",
                        value: "\(analytics.summary.totalSessionsCount)",
                        subtitle: "Avg: \(Formatters.formatDuration(seconds: analytics.summary.averageSessionSeconds, style: .short)) / session",
                        iconName: "book.pages.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                    
                    MetricCard(
                        title: "Pages Turned",
                        value: "\(analytics.summary.totalPagesRead)",
                        subtitle: "\(analytics.summary.totalBooksFinishedCount) books finished",
                        iconName: "text.book.closed.fill",
                        accentColor: BookStrideTheme.forestGreen
                    )
                }
                .padding(.horizontal, 24)
                
                // 2. Daily Reading Chart (Fixed for last 7 days)
                DailyReadingBarChart(
                    points: analytics.dailyPoints,
                    goalMinutes: Double(dailyGoalMinutes)
                )
                .padding(.horizontal, 24)
                
                // 3. Goal Consistency Breakdown
                GoalConsistencyCard(
                    summary: analytics.summary,
                    dailyPoints: analytics.dailyPoints,
                    dailyGoalMinutes: dailyGoalMinutes
                )
                .padding(.horizontal, 24)
                
                // 4. Side-by-side or stacked trends on iPad (responsive portrait/landscape)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        WeeklyTrendChart(points: analytics.weeklyTrend)
                        MonthlyActivityChart(points: analytics.monthlyActivity)
                    }
                    VStack(spacing: 20) {
                        WeeklyTrendChart(points: analytics.weeklyTrend)
                        MonthlyActivityChart(points: analytics.monthlyActivity)
                    }
                }
                .padding(.horizontal, 24)
                
                // 5. GitHub-style Reading Consistency Heatmap (Full Year with Year Nav)
                ReadingCalendarHeatmap(
                    sessions: sessionDTOs,
                    books: bookDTOs,
                    journalEntries: journalDTOs,
                    dailyGoalMinutes: dailyGoalMinutes
                )
                .padding(.horizontal, 24)
                
                // 6. Book Distribution Breakdown
                BookTimeDistributionChart(distribution: analytics.bookDistribution)
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
    
    private var readingWrappedButton: some View {
        NavigationLink {
            ReadingWrappedView()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles.rectangle.stack")
                Text("Reading Wrapped")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.callout.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(BookStrideTheme.forestGreen)
            .cornerRadius(20)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
    
    private var readingWrappedShowcaseCard: some View {
        NavigationLink {
            ReadingWrappedView()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(BookStrideTheme.forestGreen.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reading Wrapped Share Cards")
                        .font(.headline)
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("Generate and share 9:16 story & 1:1 post cards for any month or year")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("Create")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(BookStrideTheme.forestGreen)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(BookStrideTheme.forestGreen)
                }
            }
            .padding(16)
            .BookStrideCardStyle()
        }
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

