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
    public var appleBooksURL: String?
    public var importedFileName: String?
    public var sourceFormat: String?
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
        appleBooksURL: String? = nil,
        importedFileName: String? = nil,
        sourceFormat: String? = "manual",
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
        self.appleBooksURL = appleBooksURL
        self.importedFileName = importedFileName
        self.sourceFormat = sourceFormat
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.coverColorHex = try container.decodeIfPresent(String.self, forKey: .coverColorHex) ?? "forest"
        self.coverIcon = try container.decodeIfPresent(String.self, forKey: .coverIcon) ?? "book.closed"
        self.totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? ReadingStatus.currentlyReading.rawValue
        self.startDate = try container.decodeIfPresent(Date.self, forKey: .startDate)
        self.finishDate = try container.decodeIfPresent(Date.self, forKey: .finishDate)
        self.rating = try container.decodeIfPresent(Int.self, forKey: .rating)
        self.bookDescription = try container.decodeIfPresent(String.self, forKey: .bookDescription)
        self.appleBooksURL = try container.decodeIfPresent(String.self, forKey: .appleBooksURL)
        self.importedFileName = try container.decodeIfPresent(String.self, forKey: .importedFileName)
        self.sourceFormat = try container.decodeIfPresent(String.self, forKey: .sourceFormat) ?? "manual"
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.bookId = try container.decodeIfPresent(UUID.self, forKey: .bookId)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? SessionStatus.completed.rawValue
        self.accumulatedActiveSeconds = try container.decodeIfPresent(Int.self, forKey: .accumulatedActiveSeconds) ?? 0
        self.pausedDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .pausedDurationSeconds) ?? 0
        self.startPage = try container.decodeIfPresent(Int.self, forKey: .startPage)
        self.endPage = try container.decodeIfPresent(Int.self, forKey: .endPage)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? startedAt
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? endedAt ?? startedAt
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dailyMinutes = try container.decodeIfPresent(Int.self, forKey: .dailyMinutes) ?? 30
        self.dailyPages = try container.decodeIfPresent(Int.self, forKey: .dailyPages)
        self.yearlyBookTarget = try container.decodeIfPresent(Int.self, forKey: .yearlyBookTarget)
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
    
    // Backwards compatibility initializer for legacy argument ordering
    public init(
        id: UUID = UUID(),
        bookId: UUID? = nil,
        createdAt: Date = Date(),
        type: String = JournalEntryType.note.rawValue,
        title: String = "",
        content: String,
        pageNumber: Int? = nil,
        isFavorite: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.content = content.isEmpty ? title : content
        self.entryType = type
        self.pageNumber = pageNumber
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.bookId = try container.decodeIfPresent(UUID.self, forKey: .bookId)
        self.content = try container.decode(String.self, forKey: .content)
        self.entryType = try container.decodeIfPresent(String.self, forKey: .entryType) ?? JournalEntryType.note.rawValue
        self.pageNumber = try container.decodeIfPresent(Int.self, forKey: .pageNumber)
        self.isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        self.appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? "1.0.0"
        self.exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        self.books = try container.decodeIfPresent([BookDTO].self, forKey: .books) ?? []
        self.sessions = try container.decodeIfPresent([ReadingSessionDTO].self, forKey: .sessions) ?? []
        self.goals = try container.decodeIfPresent(ReadingGoalDTO.self, forKey: .goals)
        self.journalEntries = try container.decodeIfPresent([JournalEntryDTO].self, forKey: .journalEntries) ?? []
    }
}

