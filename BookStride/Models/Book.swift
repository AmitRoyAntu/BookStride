//
//  Book.swift
//  BookStride
//
//  SwiftData persistent model representing a book in the user's library.
//

import Foundation
import SwiftData

@Model
public final class Book {
    public var id: UUID = UUID()
    public var title: String = ""
    public var author: String = ""
    public var coverImageData: Data?
    public var coverColorHex: String = "forest"
    public var coverIcon: String = "book.closed"
    public var totalPages: Int?
    public var currentPage: Int?
    public var statusRawValue: String = ReadingStatus.currentlyReading.rawValue
    public var startDate: Date?
    public var finishDate: Date?
    public var rating: Int? // 1 to 5
    public var bookDescription: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    public var sessions: [ReadingSession] = []
    
    @Relationship(deleteRule: .nullify, inverse: \JournalEntry.book)
    public var journalEntries: [JournalEntry] = []
    
    public init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        coverImageData: Data? = nil,
        coverColorHex: String = "forest",
        coverIcon: String = "book.closed",
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        status: ReadingStatus = .currentlyReading,
        startDate: Date? = Date(),
        finishDate: Date? = nil,
        rating: Int? = nil,
        bookDescription: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverImageData = coverImageData
        self.coverColorHex = coverColorHex
        self.coverIcon = coverIcon
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.statusRawValue = status.rawValue
        self.startDate = startDate
        self.finishDate = finishDate
        self.rating = rating
        self.bookDescription = bookDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var status: ReadingStatus {
        get { ReadingStatus(rawValue: statusRawValue) ?? .currentlyReading }
        set { statusRawValue = newValue.rawValue }
    }
    
    public var progressFraction: Double {
        guard let total = totalPages, total > 0 else { return 0.0 }
        let current = currentPage ?? 0
        return max(0.0, min(1.0, Double(current) / Double(total)))
    }
    
    public var totalActiveReadingSeconds: Int {
        sessions
            .filter { $0.status == .completed }
            .reduce(0) { $0 + $1.activeDurationSeconds }
    }
    
    public var completedSessionCount: Int {
        sessions.filter { $0.status == .completed }.count
    }
    
    public var firstReadingDate: Date? {
        sessions
            .filter { $0.status == .completed }
            .compactMap { $0.startedAt }
            .min() ?? startDate
    }
    
    public var lastReadingDate: Date? {
        sessions
            .filter { $0.status == .completed }
            .compactMap { $0.endedAt ?? $0.startedAt }
            .max()
    }
    
    /// Total pages recorded as read across all completed sessions for this book
    public var totalRecordedPagesRead: Int {
        var total = 0
        for s in sessions where s.status == .completed {
            if let start = s.startPage, let end = s.endPage, end > start, start >= 0 {
                total += (end - start)
            }
        }
        return total
    }
    
    /// Average duration per completed session in seconds
    public var averageSessionDurationSeconds: Int {
        let count = completedSessionCount
        guard count > 0 else { return 0 }
        return totalActiveReadingSeconds / count
    }
    
    /// Calculates verified reading speed in pages per hour based only on actual session logs.
    /// Returns nil if insufficient data exists (< 5 pages or < 10 mins of valid active reading).
    public func readingSpeedPagesPerHour() -> Double? {
        let completedSessions = sessions.filter { $0.status == .completed }
        var validPages = 0
        var validSeconds = 0
        
        for s in completedSessions {
            // Require valid start and end pages, with forward progress and at least 60s active time
            if let start = s.startPage, let end = s.endPage, end > start, start >= 0, s.activeDurationSeconds >= 60 {
                validPages += (end - start)
                validSeconds += s.activeDurationSeconds
            }
        }
        
        // Data integrity rule: require at least 5 pages read and 10 minutes (600s) of active reading
        guard validPages >= 5, validSeconds >= 600 else {
            return nil
        }
        
        let hours = Double(validSeconds) / 3600.0
        guard hours > 0 else { return nil }
        return Double(validPages) / hours
    }
    
    /// Estimates completion date given remaining pages and calculated reading rate.
    /// Returns nil when data is insufficient rather than fabricating an estimate.
    public func estimatedCompletionDate(dailyReadingMinutes: Int = 30) -> Date? {
        guard status == .currentlyReading,
              let total = totalPages,
              let current = currentPage,
              total > current, current >= 0 else {
            return nil
        }
        
        guard let pagesPerHour = readingSpeedPagesPerHour(), pagesPerHour > 0 else {
            return nil
        }
        
        let remainingPages = total - current
        let hoursNeeded = Double(remainingPages) / pagesPerHour
        let dailyHours = max(0.1, Double(max(5, dailyReadingMinutes)) / 60.0)
        let daysNeeded = ceil(hoursNeeded / dailyHours)
        
        return Calendar.current.date(byAdding: .day, value: max(1, Int(daysNeeded)), to: Date())
    }
}
