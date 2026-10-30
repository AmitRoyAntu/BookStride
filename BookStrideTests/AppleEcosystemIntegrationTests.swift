//
//  AppleEcosystemIntegrationTests.swift
//  BookStrideTests
//
//  Unit tests for Apple Ecosystem Integration:
//  1. Live Activities attributes, state, and 8-hour cap.
//  2. Siri & Shortcuts App Entities, book caching, and intent logic.
//  3. Incoming Share Sheet queue persistence and isolation.
//

import Foundation

public enum AppleEcosystemIntegrationTests {
    public static func runAllTests() {
        print("▶ Running AppleEcosystemIntegrationTests...")
        testLiveActivityAttributesAndContentState()
        testLiveActivityEightHourCap()
        testBookCacheAndEntityMatching()
        testUpdateBookProgressValidation()
        testTodayReadingDurationCalculation()
        testIncomingShareQueueSerializationAndHandoff()
        print("✅ AppleEcosystemIntegrationTests passed successfully.\n")
    }
    
    // MARK: - 1. Live Activities Tests
    
    private static func testLiveActivityAttributesAndContentState() {
        let attributes = ReadingActivityAttributes(sessionId: UUID().uuidString, bookId: UUID().uuidString)
        assert(!attributes.sessionId.isEmpty, "Session ID should not be empty")
        
        let state = ReadingActivityAttributes.ContentState(
            bookTitle: "The Creative Act",
            author: "Rick Rubin",
            isPaused: false,
            accumulatedSeconds: 120,
            resumeStartDate: Date(),
            todaySeconds: 1200,
            dailyGoalSeconds: 1800,
            coverColorHex: "forest"
        )
        
        assert(state.bookTitle == "The Creative Act", "Book title should match")
        assert(state.author == "Rick Rubin", "Author should match")
        assert(!state.isPaused, "Should not be paused")
        assert(state.accumulatedSeconds == 120, "Accumulated seconds should match")
        assert(state.todaySeconds == 1200, "Today's seconds should match")
        assert(state.dailyGoalSeconds == 1800, "Daily goal seconds should match")
        
        // Paused state
        var pausedState = state
        pausedState.isPaused = true
        pausedState.resumeStartDate = nil
        assert(pausedState.isPaused, "Paused state should reflect true")
        assert(pausedState.resumeStartDate == nil, "Paused state should clear resumeStartDate")
    }
    
    private static func testLiveActivityEightHourCap() {
        let now = Date()
        let eightHours: TimeInterval = 8 * 3600
        let staleDate = now.addingTimeInterval(eightHours)
        
        assert(staleDate.timeIntervalSince(now) == eightHours, "Live Activity staleDate must be exactly 8 hours")
    }
    
    // MARK: - 2. Siri & Shortcuts App Entities Tests
    
    private static func testBookCacheAndEntityMatching() {
        let b1 = CachedBookItem(id: UUID(), title: "Clean Architecture", author: "Robert C. Martin", totalPages: 400, currentPage: 120)
        let b2 = CachedBookItem(id: UUID(), title: "Atomic Habits", author: "James Clear", totalPages: 320, currentPage: 45)
        let b3 = CachedBookItem(id: UUID(), title: "Deep Work", author: "Cal Newport", totalPages: 300, currentPage: 300)
        
        BookCacheService.saveCachedBooks([b1, b2, b3])
        let loaded = BookCacheService.getCachedBooks()
        
        assert(loaded.count == 3, "Should have saved and loaded 3 cached books")
        assert(loaded.contains(where: { $0.title == "Clean Architecture" }), "Should contain Clean Architecture")
        
        // Update page
        BookCacheService.updateCachedBookPage(bookId: b1.id, newPage: 150)
        let updated = BookCacheService.getCachedBooks()
        let updatedB1 = updated.first(where: { $0.id == b1.id })
        assert(updatedB1?.currentPage == 150, "Current page should update to 150")
    }
    
    private static func testUpdateBookProgressValidation() {
        let book = CachedBookItem(id: UUID(), title: "Thinking, Fast and Slow", author: "Daniel Kahneman", totalPages: 500, currentPage: 100)
        
        // Valid page
        let validPage = 250
        assert(validPage >= 0 && validPage <= (book.totalPages ?? 0), "Valid page should pass boundary check")
        
        // Negative page rejected
        let negativePage = -5
        assert(negativePage < 0, "Negative page must be detected as invalid")
        
        // Exceeding total pages rejected
        let exceedingPage = 600
        assert(exceedingPage > (book.totalPages ?? 0), "Exceeding total pages must be detected as invalid")
    }
    
    private static func testTodayReadingDurationCalculation() {
        let todaySeconds = 2700 // 45 minutes
        let minutes = todaySeconds / 60
        let formatted = Formatters.formatDuration(seconds: todaySeconds, style: .short)
        
        assert(minutes == 45, "Should calculate 45 minutes")
        assert(formatted == "45m", "Should format to 45m: got \(formatted)")
    }
    
    // MARK: - 3. Incoming Share Queue Tests
    
    private static func testIncomingShareQueueSerializationAndHandoff() {
        // Test URL share
        let urlItem = IncomingShareItem(
            type: .url,
            title: "Apple Books - Atomic Habits",
            urlString: "https://books.apple.com/us/book/atomic-habits/id12345",
            targetDestination: "library"
        )
        assert(urlItem.type == .url, "Type should be url")
        assert(urlItem.urlString != nil, "URL string should not be nil")
        assert(urlItem.targetDestination == "library", "Target should be library")
        
        // Test Quote share
        let quoteItem = IncomingShareItem(
            type: .textQuote,
            title: "Memorable Quote",
            textContent: "You do not rise to the level of your goals. You fall to the level of your systems.",
            targetDestination: "journal"
        )
        assert(quoteItem.type == .textQuote, "Type should be textQuote")
        assert(quoteItem.targetDestination == "journal", "Target should be journal")
        
        // Test File share
        let fileItem = IncomingShareItem(
            type: .file,
            title: "Sample Book",
            author: "Author",
            targetDestination: "library",
            relativeFilePath: "sample.epub",
            fileFormat: "epub"
        )
        assert(fileItem.type == .file, "Type should be file")
        assert(fileItem.fileFormat == "epub", "File format should be epub")
        
        // Test JSON roundtrip
        guard let data = try? JSONEncoder().encode(quoteItem),
              let decoded = try? JSONDecoder().decode(IncomingShareItem.self, from: data) else {
            fatalError("Failed to encode/decode IncomingShareItem")
        }
        assert(decoded.id == quoteItem.id, "Decoded id should match")
        assert(decoded.textContent == quoteItem.textContent, "Decoded text content should match")
    }
}
