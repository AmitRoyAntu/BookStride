//
//  TodayDashboardView.swift
//  BookStride
//
//  Main landing dashboard for BookStride on iPadOS.
//

import SwiftUI
import SwiftData

public struct TodayDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var timerService = ReadingTimerService.shared
    
    @Query(sort: \ReadingSession.startedAt, order: .reverse)
    private var allSessions: [ReadingSession]
    
    @Query(sort: \Book.updatedAt, order: .reverse)
    private var allBooks: [Book]
    
    @Query private var goals: [ReadingGoal]
    
    @State private var showingBookPicker: Bool = false
    @State private var showingAddBookSheet: Bool = false
    @State private var showingManualSessionSheet: Bool = false
    @State private var showingActiveSessionModal: Bool = false
    
    // Motivational quotes rotation
    private let motivationalQuotes = [
        "“A reader lives a thousand lives before he dies.” — George R.R. Martin",
        "“Books are a uniquely portable magic.” — Stephen King",
        "“Reading is to the mind what exercise is to the body.” — Joseph Addison",
        "“There is no friend as loyal as a book.” — Ernest Hemingway",
        "“Today a reader, tomorrow a leader.” — Margaret Fuller"
    ]
    
    public init() {}
    
    private var dailyGoalMinutes: Int {
        goals.first?.dailyMinutes ?? 30
    }
    
    private var dailyGoalSeconds: Int {
        dailyGoalMinutes * 60
    }
    
    // Compute today's active seconds and streak
    private var todayStats: (todaySeconds: Int, sessionCountToday: Int, streakDays: Int) {
        let cal = Calendar.current
        let today = Date()
        let startOfToday = cal.startOfDay(for: today)
        
        var dailyTotals: [Date: Int] = [:]
        var todaySessions = 0
        
        let completed = allSessions.filter { $0.status == .completed }
        for s in completed {
            let activeSec = s.activeDurationSeconds
            guard activeSec > 0 else { continue }
            let end = s.endedAt ?? s.startedAt.addingTimeInterval(Double(activeSec))
            let allocations = DateUtilities.splitSessionAcrossDays(
                startedAt: s.startedAt,
                endedAt: end,
                activeSeconds: activeSec,
                calendar: cal
            )
            for a in allocations {
                dailyTotals[a.date, default: 0] += a.activeSeconds
            }
            if cal.isDateInToday(s.startedAt) {
                todaySessions += 1
            }
        }
        
        // Add active session elapsed seconds to today if a session is currently open (running or paused)
        let liveSeconds = timerService.currentElapsedSeconds
        let isSessionActive = (timerService.activeState != nil)
        let todayTotal = (dailyTotals[startOfToday] ?? 0) + (isSessionActive ? liveSeconds : 0)
        dailyTotals[startOfToday] = todayTotal
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: dailyGoalMinutes,
            today: today,
            calendar: cal
        )
        
        return (todayTotal, todaySessions, streak.currentStreak)
    }
    
    private var currentlyReadingBooks: [Book] {
        allBooks.filter { $0.status == .currentlyReading }
    }
    
    private var recentSessions: [ReadingSession] {
        Array(allSessions.filter { $0.status == .completed }.prefix(3))
    }
    
    private var activeBook: Book? {
        guard let bId = timerService.activeState?.bookId else { return nil }
        return allBooks.first(where: { $0.id == bId })
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Active Reading Banner (when a timer is running or paused)
                if timerService.activeState != nil {
                    activeSessionBanner
                }
                
                // 1. Daily Progress & Streaks Card
                DailyProgressCard(
                    todaySeconds: todayStats.todaySeconds,
                    goalSeconds: dailyGoalSeconds,
                    sessionCountToday: todayStats.sessionCountToday,
                    currentStreakDays: todayStats.streakDays
                )
                
                // 2. Primary Start Reading Action & Quick Add
                startReadingControlBar
                
                // 3. Currently Reading Section
                if !currentlyReadingBooks.isEmpty {
                    currentlyReadingSection
                }
                
                // 4. Recent Reading Sessions
                if !recentSessions.isEmpty {
                    recentSessionsSection
                }
                
                // 5. Non-intrusive motivational quote
                motivationalCard
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .BookStrideBackground()
        .navigationTitle("Today")
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(
                onSelectBook: { book, startPage in
                    startNewSession(book: book, startPage: startPage)
                },
                onAddNewBook: {
                    showingAddBookSheet = true
                }
            )
        }
        .sheet(isPresented: $showingAddBookSheet) {
            AddEditBookSheet(bookToEdit: nil)
        }
        .sheet(isPresented: $showingManualSessionSheet) {
            ManualSessionSheet()
        }
        .sheet(isPresented: $showingActiveSessionModal) {
            ActiveSessionView(
                timerService: timerService,
                associatedBook: activeBook,
                onFinish: { endPage, notes in
                    saveFinishedSession(endPage: endPage, notes: notes)
                }
            )
        }
        .sheet(isPresented: $timerService.showStaleSessionAlert) {
            SessionRecoveryAlertView(timerService: timerService)
        }
    }
    
    // MARK: - Subviews
    
    private var activeSessionBanner: some View {
        Button {
            showingActiveSessionModal = true
        } label: {
            HStack(spacing: 16) {
                // Pulsing indicator
                Circle()
                    .fill(timerService.isPaused ? Color.orange : BookStrideTheme.forestGreen)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(timerService.isPaused ? "Paused Reading Session" : "Reading in Progress")
                        .font(.headline)
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    
                    Text(timerService.activeState?.bookTitle ?? "Session")
                        .font(.subheadline)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(Formatters.formatDuration(seconds: timerService.currentElapsedSeconds, style: .timer))
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            .padding()
            .BookStrideCardStyle()
        }
    }
    
    private var startReadingControlBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                startReadingButton
                logPastSessionButton
            }
            VStack(spacing: 12) {
                startReadingButton
                logPastSessionButton
            }
        }
    }
    
    private var startReadingButton: some View {
        Button {
            if timerService.activeState != nil {
                showingActiveSessionModal = true
            } else {
                showingBookPicker = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: timerService.activeState != nil ? "hourglass" : "play.circle.fill")
                    .font(.title3)
                Text(timerService.activeState != nil ? "View Active Session" : "Start Reading")
                    .font(.headline)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(BookStrideTheme.forestGreen)
            .cornerRadius(LayoutConstants.cardCornerRadius)
        }
    }
    
    private var logPastSessionButton: some View {
        Button {
            showingManualSessionSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                Text("Log Past Session")
                    .lineLimit(1)
            }
            .font(.callout.weight(.medium))
            .foregroundColor(BookStrideTheme.deepCharcoal)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(BookStrideTheme.cardLight)
            .overlay(
                RoundedRectangle(cornerRadius: LayoutConstants.cardCornerRadius)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
            .cornerRadius(LayoutConstants.cardCornerRadius)
        }
    }
    
    private var currentlyReadingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeaderView(title: "Currently Reading")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(currentlyReadingBooks) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            HStack(spacing: 14) {
                                BookCoverThumbnail(
                                    imageData: book.coverImageData,
                                    title: book.title,
                                    author: book.author,
                                    colorHex: book.coverColorHex,
                                    iconName: book.coverIcon,
                                    width: 70,
                                    height: 105,
                                    cornerRadius: 6
                                )
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(book.title)
                                        .font(.system(.headline, design: .serif))
                                        .foregroundColor(BookStrideTheme.deepCharcoal)
                                        .lineLimit(2)
                                    
                                    if !book.author.isEmpty {
                                        Text(book.author)
                                            .font(.caption)
                                            .foregroundColor(BookStrideTheme.mutedSlate)
                                            .lineLimit(1)
                                    }
                                    
                                    ProgressView(value: book.progressFraction)
                                        .tint(BookStrideTheme.forestGreen)
                                        .frame(width: 140)
                                    
                                    Text(Formatters.formatPages(current: book.currentPage, total: book.totalPages))
                                        .font(.caption2)
                                        .foregroundColor(BookStrideTheme.mutedSlate)
                                }
                            }
                            .padding(14)
                            .BookStrideCardStyle()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Recent Sessions")
            
            VStack(spacing: 10) {
                ForEach(recentSessions) { session in
                    SessionRowView(session: session)
                }
            }
        }
    }
    
    private var motivationalCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "quote.opening")
                .font(.title2)
                .foregroundColor(BookStrideTheme.forestGreen.opacity(0.6))
            
            Text(motivationalQuotes[abs(Calendar.current.component(.day, from: Date())) % motivationalQuotes.count])
                .font(.system(.subheadline, design: .serif))
                .foregroundColor(BookStrideTheme.mutedSlate)
                .italic()
            
            Spacer()
        }
        .padding(18)
        .BookStrideCardStyle()
    }
    
    // MARK: - Handlers
    
    private func startNewSession(book: Book?, startPage: Int?) {
        let title = book?.title ?? "Reading Session"
        let page = startPage ?? book?.currentPage
        let success = timerService.startSession(
            bookId: book?.id,
            bookTitle: title,
            startPage: page
        )
        if success {
            showingActiveSessionModal = true
        }
    }
    
    private func saveFinishedSession(endPage: Int?, notes: String?) {
        // Look up associated book before finishSession clears activeState, and fallback to snapshot.bookId
        let targetBook = allBooks.first(where: { $0.id == timerService.activeState?.bookId })
        guard let snapshot = timerService.finishSession(endPage: endPage, notes: notes) else { return }
        let sessionBook = targetBook ?? allBooks.first(where: { $0.id == snapshot.bookId })
        
        let session = ReadingSession(
            id: snapshot.id,
            book: sessionBook,
            startedAt: snapshot.startedAt,
            endedAt: snapshot.endedAt,
            status: .completed,
            accumulatedActiveSeconds: snapshot.accumulatedActiveSeconds,
            lastResumedAt: nil,
            lastPausedAt: nil,
            pausedDurationSeconds: snapshot.pausedDurationSeconds,
            startPage: snapshot.startPage,
            endPage: snapshot.endPage,
            notes: snapshot.notes
        )
        
        modelContext.insert(session)
        
        // Update book's current page if an ending page was recorded
        if let book = sessionBook, let end = snapshot.endPage, end > 0 {
            book.currentPage = end
            if let total = book.totalPages, end >= total {
                book.status = .finished
                if book.finishDate == nil {
                    book.finishDate = Date()
                }
            } else if book.status == .wantToRead {
                book.status = .currentlyReading
                if book.startDate == nil {
                    book.startDate = Date()
                }
            }
            book.updatedAt = Date()
        }
        
        try? modelContext.save()
    }
}

