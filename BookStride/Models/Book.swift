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
    public var appleBooksURL: String?
    public var importedFileName: String?
    public var sourceFormatRawValue: String? = BookSourceFormat.manual.rawValue
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
        appleBooksURL: String? = nil,
        importedFileName: String? = nil,
        sourceFormat: BookSourceFormat = .manual,
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
        self.appleBooksURL = appleBooksURL
        self.importedFileName = importedFileName
        self.sourceFormatRawValue = sourceFormat.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var sourceFormat: BookSourceFormat {
        get { BookSourceFormat(rawValue: sourceFormatRawValue ?? "Manual") ?? .manual }
        set { sourceFormatRawValue = newValue.rawValue }
    }
    
    public var hasAppleBooksLink: Bool {
        guard let urlStr = appleBooksURL, !urlStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return true
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
    
    /// Generates a comprehensive reading forecast using ReadingForecastService.
    public func forecast(dailyReadingMinutes: Int = 30) -> ReadingForecast {
        let sessionDTOs = sessions.map { s in
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
        return ReadingForecastService.forecastBookCompletion(
            currentPage: currentPage,
            totalPages: totalPages,
            isFinished: status == .finished,
            sessions: sessionDTOs,
            dailyReadingMinutes: dailyReadingMinutes
        )
    }
    
    /// Calculates verified reading speed in pages per hour based only on actual session logs.
    /// Returns nil if insufficient data exists (< 5 pages or < 10 mins of valid active reading).
    public func readingSpeedPagesPerHour() -> Double? {
        forecast().pagesPerHour
    }
    
    /// Estimates completion date given remaining pages and calculated reading rate.
    /// Returns nil when data is insufficient rather than fabricating an estimate.
    public func estimatedCompletionDate(dailyReadingMinutes: Int = 30) -> Date? {
        forecast(dailyReadingMinutes: dailyReadingMinutes).estimatedCompletionDate
    }
}
