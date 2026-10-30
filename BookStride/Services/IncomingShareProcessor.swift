//
//  IncomingShareProcessor.swift
//  BookStride
//
//  Processes pending items queued by the Share Extension.
//  Imports web URLs, EPUB/PDF files, and quotes cleanly into SwiftData.
//

import Foundation
import SwiftData

public enum IncomingShareProcessor {
    
    @MainActor
    public static func processPendingShares(modelContext: ModelContext) {
        let items = IncomingShareQueue.fetchPendingItems()
        guard !items.isEmpty else { return }
        
        for item in items {
            do {
                if item.targetDestination == "journal" || item.type == .textQuote {
                    importAsJournalEntry(item, in: modelContext)
                } else {
                    try importAsBook(item, in: modelContext)
                }
                IncomingShareQueue.removeItem(id: item.id)
            } catch {
                // If import fails, remove queue file to prevent loop
                IncomingShareQueue.removeItem(id: item.id)
            }
        }
        
        try? modelContext.save()
        
        // Refresh cached books for App Intents and Siri
        refreshBookCache(in: modelContext)
    }
    
    @MainActor
    private static func importAsJournalEntry(_ item: IncomingShareItem, in modelContext: ModelContext) {
        let content = item.textContent ?? item.urlString ?? item.title
        let type: JournalEntryType = (item.type == .textQuote) ? .quote : .note
        
        let entry = JournalEntry(
            book: nil,
            content: content,
            entryType: type,
            pageNumber: nil
        )
        modelContext.insert(entry)
    }
    
    @MainActor
    private static func importAsBook(_ item: IncomingShareItem, in modelContext: ModelContext) throws {
        var bookTitle = item.title.isEmpty ? "New Book" : item.title
        var author = item.author
        var totalPages: Int? = nil
        var coverData: Data? = nil
        var sourceFormat = BookSourceFormat.manual
        var fileName: String? = nil
        var appleBooksURL: String? = nil
        
        if item.type == .file, let relPath = item.relativeFilePath, let filesDir = IncomingShareQueue.filesDirectoryURL {
            let fileURL = filesDir.appendingPathComponent(relPath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let meta = try? BookImportService.extractMetadata(from: fileURL) {
                    if !meta.title.isEmpty { bookTitle = meta.title }
                    if !meta.author.isEmpty { author = meta.author }
                    totalPages = meta.totalPages
                    coverData = meta.coverImageData
                    sourceFormat = meta.format
                    fileName = meta.fileName
                    appleBooksURL = meta.appleBooksURL
                }
            }
        } else if item.type == .url, let urlStr = item.urlString {
            if AppleBooksService.isValidAppleBooksURL(urlStr) {
                appleBooksURL = urlStr
                sourceFormat = .manual
            }
        }
        
        let newBook = Book(
            title: bookTitle,
            author: author,
            coverImageData: coverData,
            coverColorHex: "forest",
            coverIcon: "book.closed",
            totalPages: totalPages,
            currentPage: 0,
            status: .wantToRead,
            appleBooksURL: appleBooksURL,
            importedFileName: fileName,
            sourceFormat: sourceFormat
        )
        modelContext.insert(newBook)
    }
    
    @MainActor
    public static func refreshBookCache(in modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Book>()
        if let books = try? modelContext.fetch(descriptor) {
            let cached = books.map {
                CachedBookItem(id: $0.id, title: $0.title, author: $0.author, totalPages: $0.totalPages, currentPage: $0.currentPage ?? 0)
            }
            BookCacheService.saveCachedBooks(cached)
        }
    }
}
