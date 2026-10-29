//
//  ReadingWrappedServiceTests.swift
//  BookStrideTests
//
//  Unit tests for Monthly and Yearly Reading Wrapped data generation.
//

import Foundation

public enum ReadingWrappedServiceTests {
    public static func runAll() {
        print("▶ Running ReadingWrappedServiceTests...")
        testMonthlyWrappedCalculations()
        testUniqueCompletedBooksNoDoubleCounting()
        testYearlyWrappedCalculations()
        testPeriodBoundariesAndCrossMidnight()
        testMostReadBookIdentification()
        testEmptyPeriods()
        testUnicodeAndLongTitles()
        print("✅ ReadingWrappedServiceTests passed successfully.\n")
    }
    
    private static func testMonthlyWrappedCalculations() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let bookId1 = UUID()
        let bookId2 = UUID()
        
        let oct1 = cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 10))!
        let oct15 = cal.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 14))!
        let oct20Finish = cal.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 18))!
        
        let books = [
            BookDTO(
                id: bookId1,
                title: "Dune",
                author: "Frank Herbert",
                coverColorHex: "terracotta",
                totalPages: 500,
                currentPage: 500,
                status: ReadingStatus.finished.rawValue,
                finishDate: oct20Finish
            ),
            BookDTO(
                id: bookId2,
                title: "Hyperion",
                author: "Dan Simmons",
                coverColorHex: "navy",
                totalPages: 400,
                currentPage: 250,
                status: ReadingStatus.currentlyReading.rawValue
            )
        ]
        
        let sessions = [
            // Session 1 on Dune: 45m (2700s) on Oct 5
            ReadingSessionDTO(
                id: UUID(),
                bookId: bookId1,
                startedAt: oct1,
                endedAt: oct1.addingTimeInterval(2700),
                status: SessionStatus.completed.rawValue,
                accumulatedActiveSeconds: 2700,
                startPage: 400,
                endPage: 450
            ),
            // Session 2 on Hyperion: 75m (4500s) on Oct 15 - longest session
            ReadingSessionDTO(
                id: UUID(),
                bookId: bookId2,
                startedAt: oct15,
                endedAt: oct15.addingTimeInterval(4500),
                status: SessionStatus.completed.rawValue,
                accumulatedActiveSeconds: 4500,
                startPage: 150,
                endPage: 210
            )
        ]
        
        let wrapped = ReadingWrappedService.computeMonthlyWrapped(
            month: 10,
            year: 2026,
            sessions: sessions,
            books: books,
            calendar: cal
        )
        
        assert(!wrapped.isEmpty, "October Wrapped should not be empty")
        assert(wrapped.totalReadingSeconds == 7200, "Total reading time should be 7200s (2 hrs), got \(wrapped.totalReadingSeconds)")
        assert(wrapped.readingDaysCount == 2, "Should have 2 reading days, got \(wrapped.readingDaysCount)")
        assert(wrapped.totalDaysInMonth == 31, "October has 31 days, got \(wrapped.totalDaysInMonth)")
        assert(wrapped.longestSessionSeconds == 4500, "Longest session should be 4500s, got \(wrapped.longestSessionSeconds)")
        assert(wrapped.longestSessionBookTitle == "Hyperion", "Longest session book should be Hyperion")
        assert(wrapped.completedBooks.count == 1, "Completed books count should be 1, got \(wrapped.completedBooks.count)")
        assert(wrapped.completedBooks.first?.title == "Dune", "Completed book should be Dune")
        assert(wrapped.mostReadBook?.title == "Hyperion", "Most read book should be Hyperion (4500s vs 2700s)")
        assert(wrapped.totalPagesRead == 110, "Total pages read should be 110 (50 + 60), got \(wrapped.totalPagesRead)")
        assert(wrapped.totalSessionsCount == 2, "Total sessions should be 2")
        assert(!wrapped.dataGroundedHighlight.isEmpty, "Highlight should be generated")
    }
    
    private static func testUniqueCompletedBooksNoDoubleCounting() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let bookId = UUID()
        let finishDate = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        
        // Even if duplicated in DTO list or multiple sessions finish, the book must appear exactly once
        let books = [
            BookDTO(
                id: bookId,
                title: "Atomic Habits",
                author: "James Clear",
                status: ReadingStatus.finished.rawValue,
                finishDate: finishDate
            ),
            BookDTO(
                id: bookId, // Same ID duplicate
                title: "Atomic Habits",
                author: "James Clear",
                status: ReadingStatus.finished.rawValue,
                finishDate: finishDate
            )
        ]
        
        let octSessions: [ReadingSessionDTO] = []
        
        let septWrapped = ReadingWrappedService.computeMonthlyWrapped(
            month: 9,
            year: 2026,
            sessions: octSessions,
            books: books,
            calendar: cal
        )
        
        assert(septWrapped.completedBooks.count == 1, "Duplicate book records must be de-duplicated to exactly 1")
    }
    
    private static func testYearlyWrappedCalculations() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let bookId1 = UUID()
        let bookId2 = UUID()
        
        let febDate = cal.date(from: DateComponents(year: 2026, month: 2, day: 10, hour: 9))!
        let marchFinish = cal.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 18))!
        let novFinish = cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 16))!
        
        let books = [
            BookDTO(
                id: bookId1,
                title: "Foundation",
                author: "Isaac Asimov",
                status: ReadingStatus.finished.rawValue,
                startDate: febDate,
                finishDate: marchFinish
            ),
            BookDTO(
                id: bookId2,
                title: "Klara and the Sun",
                author: "Kazuo Ishiguro",
                status: ReadingStatus.finished.rawValue,
                startDate: febDate,
                finishDate: novFinish
            )
        ]
        
        let sessions = [
            ReadingSessionDTO(
                id: UUID(),
                bookId: bookId1,
                startedAt: marchFinish.addingTimeInterval(-3600),
                endedAt: marchFinish,
                status: SessionStatus.completed.rawValue,
                accumulatedActiveSeconds: 3600,
                startPage: 200,
                endPage: 250
            ),
            // November session: 3 hours (10800s) -> makes November peak month
            ReadingSessionDTO(
                id: UUID(),
                bookId: bookId2,
                startedAt: novFinish.addingTimeInterval(-10800),
                endedAt: novFinish,
                status: SessionStatus.completed.rawValue,
                accumulatedActiveSeconds: 10800,
                startPage: 100,
                endPage: 200
            )
        ]
        
        let yearly = ReadingWrappedService.computeYearlyWrapped(
            year: 2026,
            sessions: sessions,
            books: books,
            calendar: cal
        )
        
        assert(!yearly.isEmpty, "Yearly wrapped should not be empty")
        assert(yearly.uniqueBooksCompleted.count == 2, "2 unique books completed, got \(yearly.uniqueBooksCompleted.count)")
        assert(yearly.totalReadingSeconds == 14400, "Total reading time should be 14400s (4 hours), got \(yearly.totalReadingSeconds)")
        assert(yearly.readingDaysCount == 2, "Reading days should be 2")
        assert(yearly.mostProductiveMonthName == "November", "Most productive month should be November, got \(yearly.mostProductiveMonthName ?? "nil")")
        assert(yearly.mostProductiveMonthSeconds == 10800, "November reading seconds should be 10800")
        assert(yearly.mostReadBook?.title == "Klara and the Sun", "Most read book should be Klara and the Sun")
        assert(yearly.milestones.count >= 2, "Should generate authentic milestones")
    }
    
    private static func testPeriodBoundariesAndCrossMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let bookId = UUID()
        let books = [
            BookDTO(id: bookId, title: "Midnight Book", status: ReadingStatus.currentlyReading.rawValue)
        ]
        
        // Session starting Oct 31 at 23:30 and ending Nov 1 at 00:30 (60 minutes = 3600s total active)
        let oct31Night = cal.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 30))!
        let nov1Morning = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 30))!
        
        let midnightSession = ReadingSessionDTO(
            id: UUID(),
            bookId: bookId,
            startedAt: oct31Night,
            endedAt: nov1Morning,
            status: SessionStatus.completed.rawValue,
            accumulatedActiveSeconds: 3600
        )
        
        let octWrapped = ReadingWrappedService.computeMonthlyWrapped(
            month: 10,
            year: 2026,
            sessions: [midnightSession],
            books: books,
            calendar: cal
        )
        
        let novWrapped = ReadingWrappedService.computeMonthlyWrapped(
            month: 11,
            year: 2026,
            sessions: [midnightSession],
            books: books,
            calendar: cal
        )
        
        // 30 mins in Oct (1800s), 30 mins in Nov (1800s)
        assert(octWrapped.totalReadingSeconds == 1800, "October should get exactly 1800s from split session, got \(octWrapped.totalReadingSeconds)")
        assert(novWrapped.totalReadingSeconds == 1800, "November should get exactly 1800s from split session, got \(novWrapped.totalReadingSeconds)")
        assert(octWrapped.readingDaysCount == 1, "October should have 1 active day")
        assert(novWrapped.readingDaysCount == 1, "November should have 1 active day")
    }
    
    private static func testMostReadBookIdentification() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let b1 = UUID()
        let b2 = UUID()
        let books = [
            BookDTO(id: b1, title: "Shorter Read", status: ReadingStatus.currentlyReading.rawValue),
            BookDTO(id: b2, title: "Dominant Book", status: ReadingStatus.currentlyReading.rawValue)
        ]
        
        let baseDate = cal.date(from: DateComponents(year: 2026, month: 5, day: 10, hour: 10))!
        let sessions = [
            ReadingSessionDTO(
                id: UUID(),
                bookId: b1,
                startedAt: baseDate,
                endedAt: baseDate.addingTimeInterval(1200),
                status: SessionStatus.completed.rawValue,
                accumulatedActiveSeconds: 1200
            ),
            ReadingSessionDTO(
                id: UUID(),
                bookId: b2,
                startedAt: baseDate.addingTimeInterval(2000),
                endedAt: baseDate.addingTimeInterval(8000),
                status: SessionStatus.completed.rawValue,
                accumulatedActiveSeconds: 6000
            )
        ]
        
        let wrapped = ReadingWrappedService.computeMonthlyWrapped(
            month: 5,
            year: 2026,
            sessions: sessions,
            books: books,
            calendar: cal
        )
        
        assert(wrapped.mostReadBook?.id == b2, "Dominant Book should be selected as most-read book")
        assert(wrapped.mostReadBook?.totalActiveSeconds == 6000, "Most read book active seconds should be 6000")
    }
    
    private static func testEmptyPeriods() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let wrappedMonth = ReadingWrappedService.computeMonthlyWrapped(
            month: 1,
            year: 2025,
            sessions: [],
            books: [],
            calendar: cal
        )
        assert(wrappedMonth.isEmpty, "Wrapped with no sessions/books should be marked empty")
        assert(wrappedMonth.totalReadingSeconds == 0, "Empty month total reading seconds should be 0")
        assert(wrappedMonth.completedBooks.isEmpty, "Empty month completed books should be empty")
        
        let wrappedYear = ReadingWrappedService.computeYearlyWrapped(
            year: 2024,
            sessions: [],
            books: [],
            calendar: cal
        )
        assert(wrappedYear.isEmpty, "Wrapped year with no sessions should be marked empty")
        assert(wrappedYear.totalReadingSeconds == 0, "Empty year total reading seconds should be 0")
    }
    
    private static func testUnicodeAndLongTitles() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let unicodeId = UUID()
        let unicodeTitle = "吾輩は猫である (I Am a Cat) — 特装版 📚✨"
        let books = [
            BookDTO(
                id: unicodeId,
                title: unicodeTitle,
                author: "夏目 漱石 (Natsume Sōseki)",
                status: ReadingStatus.finished.rawValue,
                finishDate: cal.date(from: DateComponents(year: 2026, month: 8, day: 15))!
            )
        ]
        
        let session = ReadingSessionDTO(
            id: UUID(),
            bookId: unicodeId,
            startedAt: cal.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 14))!,
            endedAt: cal.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 15))!,
            status: SessionStatus.completed.rawValue,
            accumulatedActiveSeconds: 3600
        )
        
        let wrapped = ReadingWrappedService.computeMonthlyWrapped(
            month: 8,
            year: 2026,
            sessions: [session],
            books: books,
            calendar: cal
        )
        
        assert(!wrapped.isEmpty, "Unicode book monthly wrapped should not be empty")
        assert(wrapped.completedBooks.first?.title == unicodeTitle, "Unicode title should be preserved exactly")
    }
}

