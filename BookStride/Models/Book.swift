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
    
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.book)
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
    
    /// Estimates completion date given remaining pages and reading rate (pages per hour)
    public func estimatedCompletionDate(defaultMinutesPerDay: Int = 30) -> Date? {
        guard status == .currentlyReading,
              let total = totalPages,
              let current = currentPage,
              total > current else {
            return nil
        }
        
        let remainingPages = total - current
        let completedSessions = sessions.filter { $0.status == .completed }
        let totalSeconds = completedSessions.reduce(0) { $0 + $1.activeDurationSeconds }
        
        // Calculate pages read recorded across sessions
        var pagesReadInSessions = 0
        for s in completedSessions {
            if let start = s.startPage, let end = s.endPage, end > start {
                pagesReadInSessions += (end - start)
            }
        }
        
        let pagesPerHour: Double
        if pagesReadInSessions > 5 && totalSeconds > 300 {
            let hours = Double(totalSeconds) / 3600.0
            pagesPerHour = Double(pagesReadInSessions) / hours
        } else if current > 0 && totalSeconds > 300 {
            let hours = Double(totalSeconds) / 3600.0
            pagesPerHour = Double(current) / hours
        } else {
            // Standard reading speed assumption: ~30 pages/hour (~2 mins per page)
            pagesPerHour = 30.0
        }
        
        guard pagesPerHour > 0 else { return nil }
        let hoursNeeded = Double(remainingPages) / pagesPerHour
        let dailyReadingHours = max(0.2, Double(defaultMinutesPerDay) / 60.0)
        let daysNeeded = ceil(hoursNeeded / dailyReadingHours)
        
        return Calendar.current.date(byAdding: .day, value: Int(daysNeeded), to: Date())
    }
}
