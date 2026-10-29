//
//  ModelEnums.swift
//  BookStride
//
//  Shared domain enumerations for reading status, session status, and journal types.
//

import Foundation

public enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case currentlyReading = "Currently Reading"
    case wantToRead = "Want to Read"
    case finished = "Finished"
    case abandoned = "Abandoned"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .currentlyReading: return "book.circle.fill"
        case .wantToRead: return "bookmark.circle"
        case .finished: return "checkmark.circle.fill"
        case .abandoned: return "pause.circle"
        }
    }
}

public enum SessionStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    public var id: String { rawValue }
}

public enum JournalEntryType: String, Codable, CaseIterable, Identifiable {
    case note = "Note"
    case quote = "Quote"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .note: return "note.text"
        case .quote: return "quote.opening"
        }
    }
}

