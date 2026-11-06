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
            return "Backup schema version \(v) is not supported by this version of BookStride."
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
        
        let formatterFractional = ISO8601DateFormatter()
        formatterFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterStandard = ISO8601DateFormatter()
        
        let dfPosix1 = DateFormatter()
        dfPosix1.locale = Locale(identifier: "en_US_POSIX")
        dfPosix1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        
        let dfPosix2 = DateFormatter()
        dfPosix2.locale = Locale(identifier: "en_US_POSIX")
        dfPosix2.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        
        let dfDateOnly = DateFormatter()
        dfDateOnly.locale = Locale(identifier: "en_US_POSIX")
        dfDateOnly.dateFormat = "yyyy-MM-dd"
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            if let dateStr = try? container.decode(String.self) {
                if let date = formatterFractional.date(from: dateStr) ??
                              formatterStandard.date(from: dateStr) ??
                              dfPosix1.date(from: dateStr) ??
                              dfPosix2.date(from: dateStr) ??
                              dfDateOnly.date(from: dateStr) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date from string '\(dateStr)'"
                )
            }
            
            if let epochSeconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: epochSeconds)
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO8601 string or numeric timestamp for date"
            )
        }
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
        let package: BookStrideBackupPackage
        do {
            package = try decoder.decode(BookStrideBackupPackage.self, from: data)
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                throw DataTransferError.missingRequiredFields("Missing field '\(key.stringValue)': \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                throw DataTransferError.missingRequiredFields("Type mismatch for \(type): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                throw DataTransferError.missingRequiredFields("Value not found for \(type): \(context.debugDescription)")
            case .dataCorrupted(let context):
                throw DataTransferError.importFailed("Data corrupted: \(context.debugDescription)")
            @unknown default:
                throw DataTransferError.invalidJSON
            }
        } catch {
            throw DataTransferError.importFailed(error.localizedDescription)
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
        let filename = "BookStride_Backup_\(timestamp).json"
        
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
        
        let booksURL = tempDir.appendingPathComponent("BookStride_Books_\(timestamp).csv")
        let sessionsURL = tempDir.appendingPathComponent("BookStride_Sessions_\(timestamp).csv")
        let journalURL = tempDir.appendingPathComponent("BookStride_Journal_\(timestamp).csv")
        
        let booksData = exportBooksToCSV(bookDTOs: bookDTOs).data(using: .utf8) ?? Data()
        let sessionsData = exportSessionsToCSV(sessionDTOs: sessionDTOs, bookTitles: bookTitles).data(using: .utf8) ?? Data()
        let journalData = exportJournalToCSV(journalDTOs: journalDTOs, bookTitles: bookTitles).data(using: .utf8) ?? Data()
        
        try booksData.write(to: booksURL, options: .atomic)
        try sessionsData.write(to: sessionsURL, options: .atomic)
        try journalData.write(to: journalURL, options: .atomic)
        
        return [booksURL, sessionsURL, journalURL]
    }
    
    // MARK: - Automated Local Backups
    
    /// Directory in Documents accessible via the native iOS/iPadOS Files app (On My iPad > BookStride > Backups).
    public static var localBackupsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Backups", isDirectory: true)
    }
    
    /// Writes an atomic, dated backup and a "BookStride_Latest_Backup.json" to the target directory
    /// (defaults to Documents/Backups). Retains the latest 7 dated snapshots to prevent unnecessary storage growth.
    @discardableResult
    public static func performAutomaticLocalBackup(
        package: BookStrideBackupPackage,
        targetDirectory: URL? = nil
    ) -> URL? {
        do {
            let fileManager = FileManager.default
            let dir = targetDirectory ?? localBackupsDirectory
            if !fileManager.fileExists(atPath: dir.path) {
                try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            
            let data = try exportBackupToData(package)
            
            // 1. Write the latest snapshot (always current)
            let latestURL = dir.appendingPathComponent("BookStride_Latest_Backup.json")
            try data.write(to: latestURL, options: .atomic)
            
            // 2. Write a dated daily snapshot
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let dateStr = df.string(from: package.exportedAt)
            let datedURL = dir.appendingPathComponent("BookStride_Backup_\(dateStr).json")
            try data.write(to: datedURL, options: .atomic)
            
            // 3. Prune old backups, keeping the most recent 7 dated files
            pruneOldBackups(in: dir, keepCount: 7)
            
            return latestURL
        } catch {
            print("Automatic backup failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private static func pruneOldBackups(in directory: URL, keepCount: Int) {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        let datedBackups = files.filter {
            $0.lastPathComponent.hasPrefix("BookStride_Backup_") && $0.pathExtension == "json"
        }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return date1 > date2
        }
        
        if datedBackups.count > keepCount {
            for oldFile in datedBackups[keepCount...] {
                try? fileManager.removeItem(at: oldFile)
            }
        }
    }
}
