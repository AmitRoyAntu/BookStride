//
//  IncomingShareQueue.swift
//  BookStride
//
//  Thread-safe App Group handoff queue for incoming items shared via Share Extension.
//  Decouples the extension process from the main SwiftData SQLite container.
//

import Foundation

public enum IncomingShareType: String, Codable {
    case url = "url"
    case textQuote = "textQuote"
    case file = "file"
}

public struct IncomingShareItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var type: IncomingShareType
    public var title: String
    public var author: String
    public var urlString: String?
    public var textContent: String?
    public var targetDestination: String // "library" or "journal"
    public var relativeFilePath: String?
    public var fileFormat: String? // "epub" or "pdf"
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        type: IncomingShareType,
        title: String,
        author: String = "",
        urlString: String? = nil,
        textContent: String? = nil,
        targetDestination: String = "library",
        relativeFilePath: String? = nil,
        fileFormat: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.author = author
        self.urlString = urlString
        self.textContent = textContent
        self.targetDestination = targetDestination
        self.relativeFilePath = relativeFilePath
        self.fileFormat = fileFormat
        self.createdAt = createdAt
    }
}

public enum IncomingShareQueue {
    public static let appGroupId = "group.com.amitroy.BookStride"
    
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    public static var queueDirectoryURL: URL? {
        guard let base = sharedContainerURL else { return nil }
        let dir = base.appendingPathComponent("IncomingShares", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public static var filesDirectoryURL: URL? {
        guard let queueDir = queueDirectoryURL else { return nil }
        let dir = queueDir.appendingPathComponent("Files", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    public static func enqueue(_ item: IncomingShareItem) throws {
        guard let queueDir = queueDirectoryURL else { return }
        let fileURL = queueDir.appendingPathComponent("\(item.id.uuidString).json")
        let data = try JSONEncoder().encode(item)
        try data.write(to: fileURL, options: .atomic)
    }
    
    public static func fetchPendingItems() -> [IncomingShareItem] {
        guard let queueDir = queueDirectoryURL else { return [] }
        guard let files = try? FileManager.default.contentsOfDirectory(at: queueDir, includingPropertiesForKeys: nil) else {
            return []
        }
        
        var items: [IncomingShareItem] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let item = try? JSONDecoder().decode(IncomingShareItem.self, from: data) {
                items.append(item)
            }
        }
        return items.sorted(by: { $0.createdAt < $1.createdAt })
    }
    
    public static func removeItem(id: UUID) {
        guard let queueDir = queueDirectoryURL else { return }
        let fileURL = queueDir.appendingPathComponent("\(id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    public static func clearAll() {
        guard let queueDir = queueDirectoryURL else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: queueDir, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
