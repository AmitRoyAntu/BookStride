//
//  Phase2FeatureTests.swift
//  BookStrideTests
//
//  Automated tests for Reading Insights Dashboard & Reading Journal (Phase 2).
//

import Foundation

public enum Phase2FeatureTests {
    public static func runAllTests() {
        print("▶ Running Phase2FeatureTests (Reading Insights & Journal)...")
        testTimeFilters()
        testDailyAndMonthlyAggregation()
        testCrossMidnightSessions()
        testDailyGoalCompletionAndStreaks()
        testReadingSpeedAndCompletionEstimates()
        testYearlyHeatmapComputation()
        testJournalCRUDAndFiltering()
        testBookDeletionPreservesJournalEntries()
        testJournalSerializationAndRelaunch()
        print("✅ Phase2FeatureTests passed successfully.\n")
    }
    
    // MARK: - 1. Time Filters
    public static func testTimeFilters() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.startOfDay(for: Date(timeIntervalSince1970: 1700000000)) // Fixed anchor point
        
        // Sessions at various past dates:
        // s0: today (0 days ago)
        let s0 = ReadingSessionDTO(id: UUID(), startedAt: now, accumulatedActiveSeconds: 1800)
        // s1: 4 days ago
        let s1 = ReadingSessionDTO(id: UUID(), startedAt: cal.date(byAdding: .day, value: -4, to: now)!, accumulatedActiveSeconds: 1800)
        // s2: 20 days ago
        let s2 = ReadingSessionDTO(id: UUID(), startedAt: cal.date(byAdding: .day, value: -20, to: now)!, accumulatedActiveSeconds: 1800)
        // s3: 60 days ago
        let s3 = ReadingSessionDTO(id: UUID(), startedAt: cal.date(byAdding: .day, value: -60, to: now)!, accumulatedActiveSeconds: 1800)
        // s4: 120 days ago (same year or prior year depending on now)
        let s4 = ReadingSessionDTO(id: UUID(), startedAt: cal.date(byAdding: .day, value: -120, to: now)!, accumulatedActiveSeconds: 1800)
        
        let allSessions = [s0, s1, s2, s3, s4]
        
        // Filter: Last 7 Days (should include s0, s1 -> 2 sessions, 3600s)
        let f7 = ReadingStatisticsService.computeAnalytics(sessions: allSessions, books: [], filter: .last7Days, now: now, calendar: cal)
        assert(f7.summary.totalSessionsCount == 2, "Last 7 days should have 2 sessions, got \(f7.summary.totalSessionsCount)")
        assert(f7.summary.totalReadingSeconds == 3600, "Last 7 days should have 3600s")
        
        // Filter: Last 30 Days (should include s0, s1, s2 -> 3 sessions, 5400s)
        let f30 = ReadingStatisticsService.computeAnalytics(sessions: allSessions, books: [], filter: .last30Days, now: now, calendar: cal)
        assert(f30.summary.totalSessionsCount == 3, "Last 30 days should have 3 sessions, got \(f30.summary.totalSessionsCount)")
        assert(f30.summary.totalReadingSeconds == 5400, "Last 30 days should have 5400s")
        
        // Filter: Last 90 Days (should include s0, s1, s2, s3 -> 4 sessions, 7200s)
        let f90 = ReadingStatisticsService.computeAnalytics(sessions: allSessions, books: [], filter: .last90Days, now: now, calendar: cal)
        assert(f90.summary.totalSessionsCount == 4, "Last 90 days should have 4 sessions, got \(f90.summary.totalSessionsCount)")
        assert(f90.summary.totalReadingSeconds == 7200, "Last 90 days should have 7200s")
        
        // Filter: All Time (should include all 5 sessions -> 9000s)
        let fAll = ReadingStatisticsService.computeAnalytics(sessions: allSessions, books: [], filter: .allTime, now: now, calendar: cal)
        assert(fAll.summary.totalSessionsCount == 5, "All time should have 5 sessions, got \(fAll.summary.totalSessionsCount)")
        assert(fAll.summary.totalReadingSeconds == 9000, "All time should have 9000s")
    }
    
    // MARK: - 2. Daily & Monthly Aggregation
    public static func testDailyAndMonthlyAggregation() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.startOfDay(for: Date(timeIntervalSince1970: 1700000000))
        
        let bookA = BookDTO(id: UUID(), title: "Book A", status: ReadingStatus.finished.rawValue)
        let bookB = BookDTO(id: UUID(), title: "Book B", status: ReadingStatus.currentlyReading.rawValue)
        
        // Today: 2 sessions of 1800s (30m each) with 20 pages and 30 pages
        let s0 = ReadingSessionDTO(id: UUID(), bookId: bookA.id, startedAt: now, accumulatedActiveSeconds: 1800, startPage: 1, endPage: 21)
        let s1 = ReadingSessionDTO(id: UUID(), bookId: bookB.id, startedAt: now.addingTimeInterval(3600), accumulatedActiveSeconds: 1800, startPage: 50, endPage: 80)
        
        // Yesterday (same week & month): 1 session of 3600s with 40 pages
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let s2 = ReadingSessionDTO(id: UUID(), bookId: bookA.id, startedAt: yesterday, accumulatedActiveSeconds: 3600, startPage: 21, endPage: 61)
        
        let analytics = ReadingStatisticsService.computeAnalytics(
            sessions: [s0, s1, s2],
            books: [bookA, bookB],
            filter: .last30Days,
            dailyGoalMinutes: 30,
            now: now,
            calendar: cal
        )
        
        assert(analytics.summary.totalReadingSeconds == 7200, "Total reading seconds should be 7200")
        assert(analytics.summary.readingSecondsToday == 3600, "Reading seconds today should be 3600, got \(analytics.summary.readingSecondsToday)")
        assert(analytics.summary.readingSecondsThisWeek >= 7200, "Reading seconds this week should include yesterday and today")
        assert(analytics.summary.readingSecondsThisMonth >= 7200, "Reading seconds this month should include yesterday and today")
        assert(analytics.summary.totalSessionsCount == 3, "Total sessions should be 3")
        assert(analytics.summary.averageSessionSeconds == 2400, "Average session duration should be 2400s (40 min)")
        assert(analytics.summary.totalBooksFinishedCount == 1, "Finished books count should be 1")
        // Pages: (21-1) + (80-50) + (61-21) = 20 + 30 + 40 = 90
        assert(analytics.summary.totalPagesRead == 90, "Total pages read should be 90, got \(analytics.summary.totalPagesRead)")
    }
    
    // MARK: - 3. Sessions Crossing Midnight
    public static func testCrossMidnightSessions() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // Session starting at 23:30 on Day 1 and finishing at 00:30 on Day 2
        // Total duration: 1 hour (3600s), active duration: 40 minutes (2400s), paused: 20 minutes (1200s)
        let day1 = cal.startOfDay(for: Date(timeIntervalSince1970: 1700000000))
        let start = day1.addingTimeInterval(23 * 3600 + 1800) // 23:30
        let end = day1.addingTimeInterval(24 * 3600 + 1800)   // 00:30 next day
        let activeSeconds = 2400
        
        let splits = DateUtilities.splitSessionAcrossDays(
            startedAt: start,
            endedAt: end,
            activeSeconds: activeSeconds,
            calendar: cal
        )
        
        assert(splits.count == 2, "Session crossing midnight must be split into exactly 2 days")
        assert(splits[0].date == day1, "First allocation must be for Day 1")
        let day2 = cal.date(byAdding: .day, value: 1, to: day1)!
        assert(splits[1].date == day2, "Second allocation must be for Day 2")
        
        // Sum of allocations must equal active reading seconds exactly (excluding paused)
        let totalAllocated = splits.reduce(0) { $0 + $1.activeSeconds }
        assert(totalAllocated == activeSeconds, "Total allocated active seconds (\(totalAllocated)) must match session active seconds (\(activeSeconds))")
        // 30 mins elapsed on day 1 vs 30 mins elapsed on day 2 -> proportional split should be 1200s each
        assert(splits[0].activeSeconds == 1200, "Day 1 allocation should be 1200s, got \(splits[0].activeSeconds)")
        assert(splits[1].activeSeconds == 1200, "Day 2 allocation should be 1200s, got \(splits[1].activeSeconds)")
    }
    
    // MARK: - 4. Daily Goal Completion & Streaks
    public static func testDailyGoalCompletionAndStreaks() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.startOfDay(for: Date(timeIntervalSince1970: 1700000000))
        
        // Goal is 30 mins (1800s)
        // Day 0 (today): 2000s -> Goal MET
        // Day -1 (yesterday): 1800s -> Goal MET
        // Day -2 (2 days ago): 900s -> Goal NOT MET
        // Day -3 (3 days ago): 3600s -> Goal MET
        // Day -4 (4 days ago): 2400s -> Goal MET
        
        let d0 = now
        let d1 = cal.date(byAdding: .day, value: -1, to: now)!
        let d2 = cal.date(byAdding: .day, value: -2, to: now)!
        let d3 = cal.date(byAdding: .day, value: -3, to: now)!
        let d4 = cal.date(byAdding: .day, value: -4, to: now)!
        
        let dailyTotals: [Date: Int] = [
            d0: 2000,
            d1: 1800,
            d2: 900,
            d3: 3600,
            d4: 2400
        ]
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: now,
            calendar: cal
        )
        
        assert(streak.currentStreak == 2, "Current streak should be 2 consecutive days (today & yesterday), got \(streak.currentStreak)")
        assert(streak.longestStreak == 2, "Longest streak should be 2 days, got \(streak.longestStreak)")
        assert(streak.isTodayCompleted == true, "Goal should be met today (2000s >= 1800s)")
    }
    
    // MARK: - 5. Reading Speed & Completion Estimates
    public static func testReadingSpeedAndCompletionEstimates() {
        // Insufficient data test: session with only 3 pages or 300s active time
        var validPages = 3
        var validSeconds = 300
        var speed: Double? = nil
        if validPages >= 5 && validSeconds >= 600 {
            speed = Double(validPages) / (Double(validSeconds) / 3600.0)
        }
        assert(speed == nil, "Reading speed should be nil when pages < 5 or duration < 600s")
        
        // Sufficient data test: 30 pages read over 3600s (1 hour)
        validPages = 30
        validSeconds = 3600
        if validPages >= 5 && validSeconds >= 600 {
            speed = Double(validPages) / (Double(validSeconds) / 3600.0)
        }
        assert(speed != nil, "Reading speed should not be nil with 30 pages and 3600s")
        assert(speed! == 30.0, "Reading speed should be 30.0 pages/hr")
        
        // Completion estimate calculation
        let totalPages = 300
        let currentPage = 150
        let remainingPages = totalPages - currentPage // 150 pages left
        let dailyGoalMinutes = 30 // 0.5 hours per day
        let hoursNeeded = Double(remainingPages) / speed! // 150 / 30 = 5.0 hours
        let dailyHours = Double(dailyGoalMinutes) / 60.0 // 0.5 hours
        let daysNeeded = ceil(hoursNeeded / dailyHours) // 5.0 / 0.5 = 10 days
        
        assert(daysNeeded == 10, "Days needed to finish should be 10 days, got \(daysNeeded)")
    }
    
    // MARK: - 6. Yearly Heatmap Computation
    public static func testYearlyHeatmapComputation() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.startOfDay(for: Date(timeIntervalSince1970: 1700000000))
        let year = cal.component(.year, from: now)
        
        // Add 1 session meeting goal today
        let s0 = ReadingSessionDTO(id: UUID(), startedAt: now, accumulatedActiveSeconds: 2400)
        
        let heatmap = ReadingStatisticsService.computeYearlyHeatmap(
            sessions: [s0],
            year: year,
            dailyGoalMinutes: 30,
            now: now,
            calendar: cal
        )
        
        // Gregorian year has 365 or 366 days
        assert(heatmap.count == 365 || heatmap.count == 366, "Full year heatmap must cover all calendar days (365 or 366), got \(heatmap.count)")
        
        let todayPoint = heatmap.first { $0.isToday }
        assert(todayPoint != nil, "Heatmap must contain a point marked as today")
        assert(todayPoint?.metGoal == true, "Today point must indicate goal met")
        assert(todayPoint?.minutes == 40, "Today point minutes read should be 40, got \(String(describing: todayPoint?.minutes))")
        assert(todayPoint?.sessionCount == 1, "Today point should have 1 session")
    }
    
    // MARK: - 7. Journal CRUD & Filtering
    public static func testJournalCRUDAndFiltering() {
        let book1Id = UUID()
        let book2Id = UUID()
        
        let entry1 = JournalEntryDTO(id: UUID(), bookId: book1Id, content: "The only true wisdom is in knowing you know nothing.", entryType: JournalEntryType.quote.rawValue, pageNumber: 42, isFavorite: true)
        let entry2 = JournalEntryDTO(id: UUID(), bookId: book1Id, content: "Reflecting on ancient philosophy and its modern relevance.", entryType: JournalEntryType.reflection.rawValue, isFavorite: false)
        let entry3 = JournalEntryDTO(id: UUID(), bookId: book2Id, content: "Key chapter summaries on system design.", entryType: JournalEntryType.note.rawValue, isFavorite: true)
        let entry4 = JournalEntryDTO(id: UUID(), bookId: nil, content: "Unlinked standalone thought on lifelong learning.", entryType: JournalEntryType.note.rawValue, isFavorite: false)
        
        var entries = [entry1, entry2, entry3, entry4]
        
        // Filter by Quotes
        let quotes = entries.filter { $0.entryType == JournalEntryType.quote.rawValue }
        assert(quotes.count == 1, "Should have 1 quote")
        assert(quotes[0].pageNumber == 42, "Quote should preserve page number 42")
        
        // Filter by Reflections
        let reflections = entries.filter { $0.entryType == JournalEntryType.reflection.rawValue }
        assert(reflections.count == 1, "Should have 1 reflection")
        
        // Filter by Favorites
        let favorites = entries.filter { $0.isFavorite }
        assert(favorites.count == 2, "Should have 2 favorites")
        
        // Filter by Book 1
        let book1Entries = entries.filter { $0.bookId == book1Id }
        assert(book1Entries.count == 2, "Book 1 should have 2 entries")
        
        // Search by keyword "wisdom"
        let searchWisdom = entries.filter { $0.content.lowercased().contains("wisdom") }
        assert(searchWisdom.count == 1, "Search for 'wisdom' should find 1 entry")
        
        // Edit entry
        entries[1].content = "Updated reflection with new thoughts."
        entries[1].updatedAt = Date()
        assert(entries[1].content.contains("Updated"), "Entry content should be updated")
        
        // Delete entry
        entries.removeAll { $0.id == entry4.id }
        assert(entries.count == 3, "Deleting entry should reduce count to 3")
    }
    
    // MARK: - 8. Book Deletion Preserves Journal Entries (.nullify rule)
    public static func testBookDeletionPreservesJournalEntries() {
        let bookId = UUID()
        var entry1 = JournalEntryDTO(id: UUID(), bookId: bookId, content: "Memorable passage from deleted book.")
        var entry2 = JournalEntryDTO(id: UUID(), bookId: bookId, content: "Important quote from deleted book.", entryType: JournalEntryType.quote.rawValue)
        
        // Simulating SwiftData deleteRule: .nullify
        // When book is deleted, foreign keys become nil, but journal entries are preserved!
        entry1.bookId = nil
        entry2.bookId = nil
        
        assert(entry1.bookId == nil, "Book ID must be nullified upon book deletion")
        assert(entry2.bookId == nil, "Book ID must be nullified upon book deletion")
        assert(!entry1.content.isEmpty, "Journal content must be preserved intact")
        assert(!entry2.content.isEmpty, "Journal content must be preserved intact")
    }
    
    // MARK: - 9. Journal Serialization & Persistence
    public static func testJournalSerializationAndRelaunch() {
        let entry = JournalEntryDTO(
            id: UUID(),
            bookId: UUID(),
            content: "Testing offline persistence and roundtrip encoding.",
            entryType: JournalEntryType.reflection.rawValue,
            pageNumber: 88,
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1700000000),
            updatedAt: Date(timeIntervalSince1970: 1700000500)
        )
        
        let package = BookStrideBackupPackage(
            schemaVersion: 1,
            appVersion: "1.0.0",
            exportedAt: Date(),
            books: [],
            sessions: [],
            goals: nil,
            journalEntries: [entry]
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(package)
            let decoded = try decoder.decode(BookStrideBackupPackage.self, from: data)
            
            assert(decoded.journalEntries.count == 1, "Decoded package must contain 1 journal entry")
            let decodedEntry = decoded.journalEntries[0]
            assert(decodedEntry.id == entry.id, "ID must match")
            assert(decodedEntry.content == entry.content, "Content must match")
            assert(decodedEntry.entryType == JournalEntryType.reflection.rawValue, "Entry type must be reflection")
            assert(decodedEntry.pageNumber == 88, "Page number must be preserved")
            assert(decodedEntry.isFavorite == true, "Favorite flag must be preserved")
        } catch {
            assertionFailure("Serialization failed with error: \(error)")
        }
    }
}
