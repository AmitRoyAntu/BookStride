//
//  JournalEntry.swift
//  BookStride
//
//  SwiftData persistent model representing a note or quote in the user's reading journal.
//

import Foundation
import SwiftData

@Model
public final class JournalEntry {
    public var id: UUID = UUID()
    public var content: String = ""
    public var entryTypeRawValue: String = JournalEntryType.note.rawValue
    public var pageNumber: Int?
    public var isFavorite: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public var book: Book?
    
    public init(
        id: UUID = UUID(),
        book: Book? = nil,
        content: String,
        entryType: JournalEntryType = .note,
        pageNumber: Int? = nil,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.book = book
        self.content = content
        self.entryTypeRawValue = entryType.rawValue
        self.pageNumber = pageNumber
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var entryType: JournalEntryType {
        get { JournalEntryType(rawValue: entryTypeRawValue) ?? .note }
        set { entryTypeRawValue = newValue.rawValue }
    }
}
