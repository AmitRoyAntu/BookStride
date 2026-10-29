//
//  DataExportService.swift
//  BookStride
//
//  Secure offline JSON and RFC 4180 CSV export, validation, and safe import with duplicate handling.
//

import Foundation

public enum DataTransferError: LocalizedError {
    case invalidJSON
    case unsupportedSchemaVersion(Int)
    case missingRequiredFields(String)
    case importFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "The selected file is not a valid JSON document."
        case .unsupportedSchemaVersion(let v):
            return "Backup schema version \(v) is not supported by this version of Bookstride."
        case .missingRequiredFields(let details):
            return "Backup data is missing required structure: \(details)"
        case .importFailed(let reason):
            return "Import failed: \(reason)"
        }
    }
}

public enum DataExportService {
    public static let currentSchemaVersion = 1
    
    // MARK: - JSON Handling
    
    public static func createJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    public static func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    /// Exports the full BookStride backup package into formatted JSON Data.
    public static func exportBackupToData(_ package: BookStrideBackupPackage) throws -> Data {
        let encoder = createJSONEncoder()
        return try encoder.encode(package)
    }
    
    /// Parses and strictly validates a JSON backup payload.
    public static func parseAndValidateJSON(_ data: Data) throws -> BookStrideBackupPackage {
        let decoder = createJSONDecoder()
        guard let package = try? decoder.decode(BookStrideBackupPackage.self, from: data) else {
            throw DataTransferError.invalidJSON
        }
        
        guard package.schemaVersion <= currentSchemaVersion else {
            throw DataTransferError.unsupportedSchemaVersion(package.schemaVersion)
        }
        
        // Validate items
        for book in package.books {
            if book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DataTransferError.missingRequiredFields("One or more books are missing a title.")
            }
        }
        
        return package
    }
    
    /// Writes backup JSON to a temporary file URL suitable for ShareLink or UIActivityViewController.
    public static func writeToTemporaryExportFile(_ package: BookStrideBackupPackage) throws -> URL {
        let data = try exportBackupToData(package)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = df.string(from: package.exportedAt)
        let filename = "Bookstride_Backup_\(timestamp).json"
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
    
    // MARK: - RFC 4180 CSV Export
    
    /// Escapes a CSV column according to RFC 4180.
    /// If the text contains commas, double quotes, or newlines, it is enclosed in double quotes
    /// and any internal double quotes are escaped as `""`.
    public static func escapeCSVField(_ value: String) -> String {
        let requiresEscaping = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if requiresEscaping {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return value
        }
    }
    
    /// Exports books to RFC 4180 compliant CSV string.
    public static func exportBooksToCSV(bookDTOs: [BookDTO]) -> String {
        let iso = ISO8601DateFormatter()
        var rows: [String] = [
            "ID,Title,Author,Total Pages,Current Page,Status,Rating,Completed At,Created At"
        ]
        
        for b in bookDTOs {
            let id = b.id.uuidString
            let title = escapeCSVField(b.title)
            let author = escapeCSVField(b.author)
            let totalPages = b.totalPages != nil ? "\(b.totalPages!)" : ""
            let currentPage = b.currentPage != nil ? "\(b.currentPage!)" : ""
            let status = escapeCSVField(b.status)
            let rating = b.rating != nil ? "\(b.rating!)" : ""
            let completedAt = b.finishDate != nil ? iso.string(from: b.finishDate!) : ""
            let createdAt = iso.string(from: b.createdAt)
            
            rows.append("\(id),\(title),\(author),\(totalPages),\(currentPage),\(status),\(rating),\(completedAt),\(createdAt)")
        }
        
        return rows.joined(separator: "\r\n")
    }
    
    /// Exports reading sessions to RFC 4180 compliant CSV string.
    public static func exportSessionsToCSV(sessionDTOs: [ReadingSessionDTO], bookTitles: [UUID: String] = [:]) -> String {
        let iso = ISO8601DateFormatter()
        var rows: [String] = [
            "ID,Book ID,Book Title,Started At,Ended At,Active Minutes,Start Page,End Page,Notes"
        ]
        
        for s in sessionDTOs {
            let id = s.id.uuidString
            let bookId = s.bookId?.uuidString ?? ""
            let bookTitle = escapeCSVField(s.bookId != nil ? (bookTitles[s.bookId!] ?? "") : "")
            let startedAt = iso.string(from: s.startedAt)
            let endedAt = s.endedAt != nil ? iso.string(from: s.endedAt!) : ""
            let minutes = String(format: "%.1f", Double(s.activeSeconds) / 60.0)
            let startPage = s.startPage != nil ? "\(s.startPage!)" : ""
            let endPage = s.endPage != nil ? "\(s.endPage!)" : ""
            let notes = escapeCSVField(s.notes ?? "")
            
            rows.append("\(id),\(bookId),\(bookTitle),\(startedAt),\(endedAt),\(minutes),\(startPage),\(endPage),\(notes)")
        }
        
        return rows.joined(separator: "\r\n")
    }
    
    /// Exports journal entries to RFC 4180 compliant CSV string.
    public static func exportJournalToCSV(journalDTOs: [JournalEntryDTO], bookTitles: [UUID: String] = [:]) -> String {
        let iso = ISO8601DateFormatter()
        var rows: [String] = [
            "ID,Book ID,Book Title,Type,Favorite,Page Number,Content,Created At,Updated At"
        ]
        
        for j in journalDTOs {
            let id = j.id.uuidString
            let bookId = j.bookId?.uuidString ?? ""
            let bookTitle = escapeCSVField(j.bookId != nil ? (bookTitles[j.bookId!] ?? "") : "")
            let type = escapeCSVField(j.entryType)
            let fav = j.isFavorite ? "true" : "false"
            let page = j.pageNumber != nil ? "\(j.pageNumber!)" : ""
            let content = escapeCSVField(j.content)
            let createdAt = iso.string(from: j.createdAt)
            let updatedAt = iso.string(from: j.updatedAt)
            
            rows.append("\(id),\(bookId),\(bookTitle),\(type),\(fav),\(page),\(content),\(createdAt),\(updatedAt)")
        }
        
        return rows.joined(separator: "\r\n")
    }
    
    /// Writes all three CSV files using standard UTF-8 encoding to disk and returns their file URLs.
    public static func writeCSVExportFiles(
        bookDTOs: [BookDTO],
        sessionDTOs: [ReadingSessionDTO],
        journalDTOs: [JournalEntryDTO]
    ) throws -> [URL] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let timestamp = df.string(from: Date())
        let tempDir = FileManager.default.temporaryDirectory
        
        var bookTitles: [UUID: String] = [:]
        for b in bookDTOs {
            bookTitles[b.id] = b.title
        }
        
        let booksURL = tempDir.appendingPathComponent("Bookstride_Books_\(timestamp).csv")
        let sessionsURL = tempDir.appendingPathComponent("Bookstride_Sessions_\(timestamp).csv")
        let journalURL = tempDir.appendingPathComponent("Bookstride_Journal_\(timestamp).csv")
        
        let booksData = exportBooksToCSV(bookDTOs: bookDTOs).data(using: .utf8) ?? Data()
        let sessionsData = exportSessionsToCSV(sessionDTOs: sessionDTOs, bookTitles: bookTitles).data(using: .utf8) ?? Data()
        let journalData = exportJournalToCSV(journalDTOs: journalDTOs, bookTitles: bookTitles).data(using: .utf8) ?? Data()
        
        try booksData.write(to: booksURL, options: .atomic)
        try sessionsData.write(to: sessionsURL, options: .atomic)
        try journalData.write(to: journalURL, options: .atomic)
        
        return [booksURL, sessionsURL, journalURL]
    }
}
