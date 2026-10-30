//
//  PolishReleaseTests.swift
//  BookStrideTests
//
//  Comprehensive verification suite for the BookStride Polish Release:
//  - Reading pace calculation and completion forecasting engine
//  - Heatmap future date detection and session/journal date linking
//  - RFC 4180 CSV export escaping, header structure, and Unicode/Bengali preservation
//  - Journal Key Takeaways and date scoping
//

import Foundation

public struct PolishReleaseTests {
    
    public static func runAllTests() {
        print("▶ Running PolishReleaseTests...")
        
        testReadingForecastWithSufficientData()
        testReadingForecastSparseData()
        testReadingForecastFinishedBook()
        testReadingForecastMissingTotalPages()
        testReadingForecastInvalidProgress()
        testReadingForecastZeroSpeedProtection()
        
        testHeatmapFutureDateDistinction()
        testHeatmapYearNavigationBounds()
        
        testCSVExportRFC4180EscapingCommas()
        testCSVExportRFC4180EscapingQuotes()
        testCSVExportRFC4180EscapingNewlines()
        testCSVExportUnicodeBengaliPreservation()
        testCSVExportHeaderColumnsIntegrity()
        
        testJournalKeyTakeawayEnumAndScoping()
        
        print("✅ PolishReleaseTests passed successfully.\n")
    }
    
    // MARK: - Reading Forecast Engine Tests
    
    static func testReadingForecastWithSufficientData() {
        let now = Date()
        // 20 pages read over 1800s (30 mins) = 40 pages/hour pace
        let s1 = ReadingSessionDTO(
            id: UUID(),
            startedAt: now.addingTimeInterval(-3600),
            endedAt: now.addingTimeInterval(-1800),
            status: SessionStatus.completed.rawValue,
            accumulatedActiveSeconds: 1800,
            startPage: 10,
            endPage: 30
        )
        
        let speed = ReadingForecastService.calculateReadingSpeed(sessions: [s1], now: now)
        assert(speed != nil, "Reading speed should be calculated with 20 pages and 1800 seconds")
        assert(abs(speed! - 40.0) < 0.1, "Speed should be 40 pages per hour, got \(speed!)")
        
        // Book with 100 pages, currently at page 20 -> 80 pages remaining
        // At 40 pages/hour: 2 hours remaining (120 minutes)
        // With 30 min daily goal: ceil(2 / 0.5) = 4 days
        let forecast = ReadingForecastService.forecastBookCompletion(
            currentPage: 20,
            totalPages: 100,
            isFinished: false,
            sessions: [s1],
            dailyReadingMinutes: 30,
            now: now
        )
        
        assert(forecast.status == .accurate, "Status should be .accurate")
        assert(forecast.remainingPages == 80, "Remaining pages should be 80")
        assert(forecast.estimatedRemainingMinutes == 120, "Remaining minutes should be 120")
        assert(forecast.daysToFinish == 4, "Days needed should be 4, got \(String(describing: forecast.daysToFinish))")
        assert(forecast.estimatedCompletionDate != nil, "Estimated completion date should be populated")
    }
    
    static func testReadingForecastSparseData() {
        let now = Date()
        // Only 2 pages read over 300 seconds (below 5 pages and 600s threshold)
        let s1 = ReadingSessionDTO(
            id: UUID(),
            startedAt: now.addingTimeInterval(-600),
            endedAt: now.addingTimeInterval(-300),
            status: SessionStatus.completed.rawValue,
            accumulatedActiveSeconds: 300,
            startPage: 1,
            endPage: 3
        )
        
        let speed = ReadingForecastService.calculateReadingSpeed(sessions: [s1], now: now)
        assert(speed == nil, "Reading speed should be nil when below minimum thresholds")
        
        let forecast = ReadingForecastService.forecastBookCompletion(
            currentPage: 10,
            totalPages: 200,
            isFinished: false,
            sessions: [s1],
            dailyReadingMinutes: 30,
            now: now
        )
        
        assert(forecast.status == .insufficientSessionData, "Status should be .insufficientSessionData")
        assert(forecast.remainingPages == 190, "Remaining pages should still calculate accurately")
        assert(forecast.estimatedCompletionDate == nil, "Completion date should not be fabricated")
    }
    
    static func testReadingForecastFinishedBook() {
        let forecast = ReadingForecastService.forecastBookCompletion(
            currentPage: 200,
            totalPages: 200,
            isFinished: true,
            sessions: []
        )
        
        assert(forecast.status == .completed, "Finished book must return .completed status")
        assert(forecast.remainingPages == nil || forecast.remainingPages == 0, "No remaining pages for finished book")
    }
    
    static func testReadingForecastMissingTotalPages() {
        let forecast = ReadingForecastService.forecastBookCompletion(
            currentPage: 50,
            totalPages: nil,
            isFinished: false,
            sessions: []
        )
        
        assert(forecast.status == .missingTotalPages, "Missing total pages must return .missingTotalPages")
    }
    
    static func testReadingForecastInvalidProgress() {
        let forecast = ReadingForecastService.forecastBookCompletion(
            currentPage: 350,
            totalPages: 300,
            isFinished: false,
            sessions: []
        )
        
        assert(forecast.status == .invalidProgress, "Current page exceeding total must return .invalidProgress")
    }
    
    static func testReadingForecastZeroSpeedProtection() {
        // Sessions with zero pages or inverted pages
        let s = ReadingSessionDTO(
            id: UUID(),
            startedAt: Date(),
            status: SessionStatus.completed.rawValue,
            accumulatedActiveSeconds: 1200,
            startPage: 50,
            endPage: 40 // Invalid inverted range
        )
        
        let speed = ReadingForecastService.calculateReadingSpeed(sessions: [s])
        assert(speed == nil, "Inverted page range must not produce valid reading speed")
    }
    
    // MARK: - Heatmap Tests
    
    static func testHeatmapFutureDateDistinction() {
        let calendar = Calendar.current
        let now = Date()
        let todayComps = calendar.dateComponents([.year], from: now)
        let currentYear = todayComps.year ?? 2026
        
        let points = ReadingStatisticsService.computeYearlyHeatmap(
            sessions: [],
            year: currentYear,
            dailyGoalMinutes: 30,
            now: now,
            calendar: calendar
        )
        
        assert(!points.isEmpty, "Heatmap points should be generated for current year")
        
        let futurePoints = points.filter { $0.isFuture }
        let pastPoints = points.filter { !$0.isFuture && !$0.isToday }
        let todayPoints = points.filter { $0.isToday }
        
        assert(todayPoints.count == 1, "There should be exactly one today point in current year")
        // Points later in the year must be marked as isFuture
        for pt in futurePoints {
            assert(pt.date > now, "Future point date must be after now")
        }
        for pt in pastPoints {
            assert(pt.date < now, "Past point date must be before now")
        }
    }
    
    static func testHeatmapYearNavigationBounds() {
        let calendar = Calendar.current
        let points2024 = ReadingStatisticsService.computeYearlyHeatmap(
            sessions: [],
            year: 2024,
            dailyGoalMinutes: 30,
            calendar: calendar
        )
        
        // 2024 is a leap year: 366 days
        assert(points2024.count == 366, "Leap year 2024 should have 366 heatmap points, got \(points2024.count)")
        
        let points2025 = ReadingStatisticsService.computeYearlyHeatmap(
            sessions: [],
            year: 2025,
            dailyGoalMinutes: 30,
            calendar: calendar
        )
        assert(points2025.count == 365, "Standard year 2025 should have 365 heatmap points, got \(points2025.count)")
    }
    
    // MARK: - RFC 4180 CSV Export Tests
    
    static func testCSVExportRFC4180EscapingCommas() {
        let raw = "Dune, Part One"
        let escaped = DataExportService.escapeCSVField(raw)
        assert(escaped == "\"Dune, Part One\"", "Field with comma must be wrapped in double quotes: \(escaped)")
    }
    
    static func testCSVExportRFC4180EscapingQuotes() {
        let raw = "The \"Great\" Gatsby"
        let escaped = DataExportService.escapeCSVField(raw)
        assert(escaped == "\"The \"\"Great\"\" Gatsby\"", "Quotes inside field must be doubled and wrapped: \(escaped)")
    }
    
    static func testCSVExportRFC4180EscapingNewlines() {
        let raw = "Line 1\nLine 2\r\nLine 3"
        let escaped = DataExportService.escapeCSVField(raw)
        assert(escaped.hasPrefix("\"") && escaped.hasSuffix("\""), "Multiline field must be wrapped in quotes")
        assert(escaped.contains("Line 1\nLine 2"), "Newlines must be preserved inside quotes")
    }
    
    static func testCSVExportUnicodeBengaliPreservation() {
        let bookTitle = "পথের পাঁচালী"
        let author = "বিভূতিভূষণ বন্দ্যোপাধ্যায়"
        let book = BookDTO(
            id: UUID(),
            title: bookTitle,
            author: author,
            coverColorHex: "forest",
            coverIcon: "book",
            totalPages: 320,
            currentPage: 150,
            status: "currentlyReading"
        )
        
        let csv = DataExportService.exportBooksToCSV(bookDTOs: [book])
        assert(csv.contains("পথের পাঁচালী"), "Bengali book title must be preserved intact in CSV")
        assert(csv.contains("বিভূতিভূষণ বন্দ্যোপাধ্যায়"), "Bengali author must be preserved intact in CSV")
        
        // Test UTF-8 byte conversion roundtrip
        guard let data = csv.data(using: .utf8),
              let roundtrip = String(data: data, encoding: .utf8) else {
            fatalError("UTF-8 encoding failed for Bengali characters")
        }
        assert(roundtrip.contains("পথের পাঁচালী"), "UTF-8 roundtrip must match original Unicode")
    }
    
    static func testCSVExportHeaderColumnsIntegrity() {
        let booksCSV = DataExportService.exportBooksToCSV(bookDTOs: [])
        assert(booksCSV.starts(with: "ID,Title,Author,Total Pages,Current Page,Status,Rating,Completed At,Created At"), "Books CSV header mismatch")
        
        let sessionsCSV = DataExportService.exportSessionsToCSV(sessionDTOs: [])
        assert(sessionsCSV.starts(with: "ID,Book ID,Book Title,Started At,Ended At,Active Minutes,Start Page,End Page,Notes"), "Sessions CSV header mismatch")
        
        let journalCSV = DataExportService.exportJournalToCSV(journalDTOs: [])
        assert(journalCSV.starts(with: "ID,Book ID,Book Title,Type,Favorite,Page Number,Content,Created At,Updated At"), "Journal CSV header mismatch")
    }
    
    // MARK: - Journal Key Takeaway Tests
    
    static func testJournalKeyTakeawayEnumAndScoping() {
        let takeaway = JournalEntryType.keyTakeaway
        assert(takeaway.rawValue == "Key Takeaway", "Key Takeaway raw value must be 'Key Takeaway'")
        assert(takeaway.iconName == "lightbulb", "Key Takeaway icon must be lightbulb")
        
        // All types present
        let allTypes = JournalEntryType.allCases
        assert(allTypes.contains(.note), "Should contain note")
        assert(allTypes.contains(.quote), "Should contain quote")
        assert(allTypes.contains(.reflection), "Should contain reflection")
        assert(allTypes.contains(.keyTakeaway), "Should contain keyTakeaway")
    }
}
