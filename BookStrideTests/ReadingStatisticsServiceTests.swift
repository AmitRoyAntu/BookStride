//
//  ReadingStatisticsServiceTests.swift
//  BookStrideTests
//
//  Unit tests for analytics calculation, daily breakdown, averages, and chart points.
//

import Foundation

public enum ReadingStatisticsServiceTests {
    public static func runAllTests() {
        print("▶ Running ReadingStatisticsServiceTests...")
        testTotalDurationExcludesPause()
        testAnalyticsAggregationAndAverages()
        testBookDistributionAggregation()
        testHeatmapIntensityMapping()
        print("✅ ReadingStatisticsServiceTests passed successfully.\n")
    }
    
    private static func testTotalDurationExcludesPause() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = t0.addingTimeInterval(3600) // 1 hour elapsed, but 15 minutes was paused
        
        let session = ReadingSessionDTO(
            id: UUID(),
            bookId: nil,
            startedAt: t0,
            endedAt: t1,
            status: SessionStatus.completed.rawValue,
            accumulatedActiveSeconds: 2700, // 45 minutes active
            pausedDurationSeconds: 900 // 15 minutes paused
        )
        
        assert(session.activeSeconds == 2700, "Active seconds must exclude paused time")
    }
    
    private static func testAnalyticsAggregationAndAverages() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        
        let book1 = BookDTO(id: UUID(), title: "Book A", status: ReadingStatus.finished.rawValue)
        let book2 = BookDTO(id: UUID(), title: "Book B", status: ReadingStatus.currentlyReading.rawValue)
        
        // 3 sessions: 1800s, 3600s, 1800s = 7200s total active time
        let s1 = ReadingSessionDTO(id: UUID(), bookId: book1.id, startedAt: now, endedAt: now.addingTimeInterval(1800), accumulatedActiveSeconds: 1800, startPage: 1, endPage: 25)
        let s2 = ReadingSessionDTO(id: UUID(), bookId: book1.id, startedAt: now, endedAt: now.addingTimeInterval(3600), accumulatedActiveSeconds: 3600, startPage: 25, endPage: 60)
        let s3 = ReadingSessionDTO(id: UUID(), bookId: book2.id, startedAt: cal.date(byAdding: .day, value: -1, to: now)!, endedAt: now, accumulatedActiveSeconds: 1800, startPage: 10, endPage: 30)
        
        let analytics = ReadingStatisticsService.computeAnalytics(
            sessions: [s1, s2, s3],
            books: [book1, book2],
            filter: .last7Days,
            dailyGoalMinutes: 30,
            now: now,
            calendar: cal
        )
        
        assert(analytics.summary.totalReadingSeconds == 7200, "Total reading seconds should be 7200, got \(analytics.summary.totalReadingSeconds)")
        assert(analytics.summary.totalSessionsCount == 3, "Total sessions should be 3")
        assert(analytics.summary.totalBooksFinishedCount == 1, "Finished books should be 1")
        assert(analytics.summary.averageSessionSeconds == 2400, "Average session should be 2400s (40 min)")
        // Pages: (25-1) + (60-25) + (30-10) = 24 + 35 + 20 = 79 pages
        assert(analytics.summary.totalPagesRead == 79, "Total pages read should be 79, got \(analytics.summary.totalPagesRead)")
    }
    
    private static func testBookDistributionAggregation() {
        let b1 = BookDTO(id: UUID(), title: "Mastery", coverColorHex: "forest")
        let b2 = BookDTO(id: UUID(), title: "Deep Work", coverColorHex: "navy")
        
        let s1 = ReadingSessionDTO(id: UUID(), bookId: b1.id, accumulatedActiveSeconds: 3600)
        let s2 = ReadingSessionDTO(id: UUID(), bookId: b2.id, accumulatedActiveSeconds: 1800)
        let s3 = ReadingSessionDTO(id: UUID(), bookId: b1.id, accumulatedActiveSeconds: 1800)
        
        let analytics = ReadingStatisticsService.computeAnalytics(
            sessions: [s1, s2, s3],
            books: [b1, b2],
            filter: .allTime,
            dailyGoalMinutes: 30
        )
        
        assert(analytics.bookDistribution.count == 2, "Should have 2 books in distribution")
        // Mastery should be first with 5400s (90 mins)
        assert(analytics.bookDistribution[0].bookId == b1.id, "Top book should be Mastery")
        assert(analytics.bookDistribution[0].minutes == 90.0, "Mastery should have 90 minutes")
        assert(analytics.bookDistribution[1].minutes == 30.0, "Deep Work should have 30 minutes")
    }
    
    private static func testHeatmapIntensityMapping() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        
        let s1 = ReadingSessionDTO(id: UUID(), startedAt: now, accumulatedActiveSeconds: 1900) // Goal met
        let analytics = ReadingStatisticsService.computeAnalytics(
            sessions: [s1],
            books: [],
            filter: .allTime,
            dailyGoalMinutes: 30,
            now: now,
            calendar: cal
        )
        
        let todayPoint = analytics.heatmapPoints.first { cal.isDate($0.date, inSameDayAs: now) }
        assert(todayPoint != nil, "Today point must exist in heatmap")
        assert(todayPoint?.intensity == 4, "Intensity should be 4 when goal is met, got \(String(describing: todayPoint?.intensity))")
    }
}

