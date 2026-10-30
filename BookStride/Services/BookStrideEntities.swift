//
//  BookStrideEntities.swift
//  BookStride
//
//  AppEntity definitions and queries for Siri, Shortcuts, and App Intents.
//

import Foundation
#if canImport(AppIntents)
import AppIntents
#endif

public struct CachedBookItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var author: String
    public var totalPages: Int?
    public var currentPage: Int
    
    public init(id: UUID, title: String, author: String = "", totalPages: Int? = nil, currentPage: Int = 0) {
        self.id = id
        self.title = title
        self.author = author
        self.totalPages = totalPages
        self.currentPage = currentPage
    }
}

public enum BookCacheService {
    public static let cacheKey = "BookStride_BookCache_v1"
    
    public static func getCachedBooks() -> [CachedBookItem] {
        let defaults = AppGroupConfig.sharedDefaults
        if let data = defaults.data(forKey: cacheKey),
           let books = try? JSONDecoder().decode([CachedBookItem].self, from: data) {
            return books
        }
        return []
    }
    
    public static func saveCachedBooks(_ books: [CachedBookItem]) {
        let defaults = AppGroupConfig.sharedDefaults
        if let data = try? JSONEncoder().encode(books) {
            defaults.set(data, forKey: cacheKey)
            if defaults != .standard {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
        }
    }
    
    public static func updateCachedBookPage(bookId: UUID, newPage: Int) {
        var books = getCachedBooks()
        if let idx = books.firstIndex(where: { $0.id == bookId }) {
            books[idx].currentPage = newPage
            saveCachedBooks(books)
        }
    }
}

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct BookEntity: AppEntity {
    public static var defaultQuery = BookQuery()
    
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"
    
    public var id: UUID
    public var title: String
    public var author: String
    public var totalPages: Int?
    public var currentPage: Int
    
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: author.isEmpty ? nil : "\(author)"
        )
    }
    
    public init(id: UUID, title: String, author: String = "", totalPages: Int? = nil, currentPage: Int = 0) {
        self.id = id
        self.title = title
        self.author = author
        self.totalPages = totalPages
        self.currentPage = currentPage
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, *)
public struct BookQuery: EntityQuery {
    public init() {}
    
    public func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        let cached = BookCacheService.getCachedBooks()
        return cached.filter { identifiers.contains($0.id) }.map {
            BookEntity(id: $0.id, title: $0.title, author: $0.author, totalPages: $0.totalPages, currentPage: $0.currentPage)
        }
    }
    
    public func suggestedEntities() async throws -> [BookEntity] {
        let cached = BookCacheService.getCachedBooks()
        return cached.map {
            BookEntity(id: $0.id, title: $0.title, author: $0.author, totalPages: $0.totalPages, currentPage: $0.currentPage)
        }
    }
    
    public func entities(matching string: String) async throws -> [BookEntity] {
        let cached = BookCacheService.getCachedBooks()
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return try await suggestedEntities() }
        
        return cached.filter {
            $0.title.lowercased().contains(query) || $0.author.lowercased().contains(query)
        }.map {
            BookEntity(id: $0.id, title: $0.title, author: $0.author, totalPages: $0.totalPages, currentPage: $0.currentPage)
        }
    }
}
#endif

