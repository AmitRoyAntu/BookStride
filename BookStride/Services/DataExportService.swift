//
//  DataExportService.swift
//  BookStride
//
//  Secure offline JSON export, validation, and safe import with duplicate handling.
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
}

