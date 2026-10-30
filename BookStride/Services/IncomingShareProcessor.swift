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
        var totalPages: Int? = item.totalPages
        var coverData: Data? = item.coverImageData
        var sourceFormat = BookSourceFormat.manual
        var fileName: String? = nil
        var appleBooksURL: String? = item.urlString
        
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
    
    /// Processes incoming share items transmitted directly via the `bookstride://incoming` URL scheme.
    /// Provides zero-dependency handoff when App Groups are not provisioned on the host device.
    @MainActor
    @discardableResult
    public static func processDirectURL(_ url: URL, in modelContext: ModelContext) -> Bool {
        guard url.scheme == "bookstride", url.host == "incoming" else { return false }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        
        let queryMap = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value != nil ? (item.name, item.value!) : nil
        })
        
        // 1. Try decoding structured base64 payload if provided
        if let base64 = queryMap["data"], let data = Data(base64Encoded: base64),
           let shareItem = try? JSONDecoder().decode(IncomingShareItem.self, from: data) {
            do {
                if shareItem.targetDestination == "journal" || shareItem.type == .textQuote {
                    importAsJournalEntry(shareItem, in: modelContext)
                } else {
                    try importAsBook(shareItem, in: modelContext)
                }
                try? modelContext.save()
                refreshBookCache(in: modelContext)
                return true
            } catch {
                // Fall back to query item extraction below
            }
        }
        
        // 2. Extract from standard query parameters
        guard let title = queryMap["title"], !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = queryMap["author"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let appleBooksURL = queryMap["url"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let totalPages = queryMap["pages"].flatMap(Int.init)
        let destination = queryMap["dest"] ?? "library"
        let format = queryMap["format"]
        
        if destination == "journal" {
            let entry = JournalEntry(
                book: nil,
                content: "Shared from Apple Books: \(cleanTitle)\(author.isEmpty ? "" : " by \(author)")\n\(appleBooksURL ?? "")",
                entryType: .note,
                pageNumber: nil
            )
            modelContext.insert(entry)
        } else {
            // Check for duplicate in SwiftData
            var descriptor = FetchDescriptor<Book>()
            descriptor.fetchLimit = 100
            let existingBooks = (try? modelContext.fetch(descriptor)) ?? []
            let isDuplicate = existingBooks.contains { b in
                b.title.localizedCaseInsensitiveCompare(cleanTitle) == .orderedSame &&
                (author.isEmpty || b.author.localizedCaseInsensitiveCompare(author) == .orderedSame)
            }
            
            if !isDuplicate {
                let newBook = Book(
                    title: cleanTitle,
                    author: author,
                    coverImageData: nil,
                    coverColorHex: "forest",
                    coverIcon: "book.closed",
                    totalPages: totalPages,
                    currentPage: 0,
                    status: .wantToRead,
                    appleBooksURL: (appleBooksURL?.isEmpty == false) ? appleBooksURL : nil,
                    importedFileName: nil,
                    sourceFormat: (format?.lowercased() == "epub") ? .epub : ((format?.lowercased() == "pdf") ? .pdf : .manual)
                )
                modelContext.insert(newBook)
            }
        }
        
        try? modelContext.save()
        refreshBookCache(in: modelContext)
        return true
    }
}
