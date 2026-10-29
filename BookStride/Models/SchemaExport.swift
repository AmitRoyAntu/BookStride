//
//  SchemaExport.swift
//  BookStride
//
//  Transfer and backup DTO models for JSON export, import, and standalone testing.
//

import Foundation

public struct BookDTO: Codable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var author: String
    public var coverColorHex: String
    public var coverIcon: String
    public var totalPages: Int?
    public var currentPage: Int?
    public var status: String
    public var startDate: Date?
    public var finishDate: Date?
    public var rating: Int?
    public var bookDescription: String?
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        coverColorHex: String = "forest",
        coverIcon: String = "book.closed",
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        status: String = ReadingStatus.currentlyReading.rawValue,
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
        self.coverColorHex = coverColorHex
        self.coverIcon = coverIcon
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.status = status
        self.startDate = startDate
        self.finishDate = finishDate
        self.rating = rating
        self.bookDescription = bookDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReadingSessionDTO: Codable, Identifiable, Equatable {
    public let id: UUID
    public var bookId: UUID?
    public var startedAt: Date
    public var endedAt: Date?
    public var status: String
    public var accumulatedActiveSeconds: Int
    public var pausedDurationSeconds: Int
    public var startPage: Int?
    public var endPage: Int?
    public var notes: String?
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        bookId: UUID? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: String = SessionStatus.completed.rawValue,
        accumulatedActiveSeconds: Int = 0,
        pausedDurationSeconds: Int = 0,
        startPage: Int? = nil,
        endPage: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.accumulatedActiveSeconds = accumulatedActiveSeconds
        self.pausedDurationSeconds = pausedDurationSeconds
        self.startPage = startPage
        self.endPage = endPage
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var activeSeconds: Int {
        if accumulatedActiveSeconds > 0 {
            return accumulatedActiveSeconds
        } else if let end = endedAt {
            let total = Int(max(0, end.timeIntervalSince(startedAt)))
            return max(0, total - pausedDurationSeconds)
        }
        return 0
    }
}

public struct ReadingGoalDTO: Codable, Equatable {
    public var dailyMinutes: Int
    public var dailyPages: Int?
    public var yearlyBookTarget: Int?
    
    public init(dailyMinutes: Int = 30, dailyPages: Int? = nil, yearlyBookTarget: Int? = nil) {
        self.dailyMinutes = dailyMinutes
        self.dailyPages = dailyPages
        self.yearlyBookTarget = yearlyBookTarget
    }
}

public struct JournalEntryDTO: Codable, Identifiable, Equatable {
    public let id: UUID
    public var bookId: UUID?
    public var content: String
    public var entryType: String
    public var pageNumber: Int?
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        bookId: UUID? = nil,
        content: String,
        entryType: String = JournalEntryType.note.rawValue,
        pageNumber: Int? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.content = content
        self.entryType = entryType
        self.pageNumber = pageNumber
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct BookStrideBackupPackage: Codable, Equatable {
    public var schemaVersion: Int
    public var appVersion: String
    public var exportedAt: Date
    public var books: [BookDTO]
    public var sessions: [ReadingSessionDTO]
    public var goals: ReadingGoalDTO?
    public var journalEntries: [JournalEntryDTO]
    
    public init(
        schemaVersion: Int = 1,
        appVersion: String = "1.0.0",
        exportedAt: Date = Date(),
        books: [BookDTO] = [],
        sessions: [ReadingSessionDTO] = [],
        goals: ReadingGoalDTO? = nil,
        journalEntries: [JournalEntryDTO] = []
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.books = books
        self.sessions = sessions
        self.goals = goals
        self.journalEntries = journalEntries
    }
}

