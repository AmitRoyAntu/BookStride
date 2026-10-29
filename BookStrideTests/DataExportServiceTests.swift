//
//  DataExportServiceTests.swift
//  BookStrideTests
//
//  Unit tests for JSON export, backup encoding, validation, and error detection.
//

import Foundation

public enum DataExportServiceTests {
    public static func runAllTests() {
        print("▶ Running DataExportServiceTests...")
        testExportAndImportRoundtrip()
        testInvalidSchemaVersionRejection()
        testMissingBookTitleRejection()
        print("✅ DataExportServiceTests passed successfully.\n")
    }
    
    private static func testExportAndImportRoundtrip() {
        let b1 = BookDTO(id: UUID(), title: "Thinking, Fast and Slow", author: "Daniel Kahneman", totalPages: 499, currentPage: 120)
        let s1 = ReadingSessionDTO(id: UUID(), bookId: b1.id, startedAt: Date(), endedAt: Date().addingTimeInterval(1800), accumulatedActiveSeconds: 1800, startPage: 90, endPage: 120, notes: "Fascinating chapter on heuristics.")
        let g1 = ReadingGoalDTO(dailyMinutes: 45, dailyPages: 25, yearlyBookTarget: 30)
        let j1 = JournalEntryDTO(id: UUID(), bookId: b1.id, content: "Nothing in life is as important as you think it is, while you are thinking about it.", entryType: "Quote", pageNumber: 115, isFavorite: true)
        
        let package = BookStrideBackupPackage(
            schemaVersion: 1,
            appVersion: "1.0.0",
            exportedAt: Date(),
            books: [b1],
            sessions: [s1],
            goals: g1,
            journalEntries: [j1]
        )
        
        do {
            let data = try DataExportService.exportBackupToData(package)
            assert(!data.isEmpty, "Exported data must not be empty")
            
            let parsed = try DataExportService.parseAndValidateJSON(data)
            assert(parsed.books.count == 1, "Parsed books count should match")
            assert(parsed.books[0].title == "Thinking, Fast and Slow", "Book title should match")
            assert(parsed.sessions.count == 1, "Parsed sessions count should match")
            assert(parsed.sessions[0].activeSeconds == 1800, "Active seconds should match")
            assert(parsed.journalEntries.count == 1, "Parsed journal entries count should match")
            assert(parsed.goals?.dailyMinutes == 45, "Goal daily minutes should match")
        } catch {
            assertionFailure("Export roundtrip failed with error: \(error)")
        }
    }
    
    private static func testInvalidSchemaVersionRejection() {
        let invalidPackage = BookStrideBackupPackage(schemaVersion: 999) // Future unsupported schema
        do {
            let data = try DataExportService.exportBackupToData(invalidPackage)
            _ = try DataExportService.parseAndValidateJSON(data)
            assertionFailure("Should have thrown unsupportedSchemaVersion error")
        } catch DataTransferError.unsupportedSchemaVersion(let v) {
            assert(v == 999, "Error version should be 999")
        } catch {
            assertionFailure("Unexpected error type: \(error)")
        }
    }
    
    private static func testMissingBookTitleRejection() {
        let badBook = BookDTO(id: UUID(), title: "   ") // Blank title
        let package = BookStrideBackupPackage(books: [badBook])
        do {
            let data = try DataExportService.exportBackupToData(package)
            _ = try DataExportService.parseAndValidateJSON(data)
            assertionFailure("Should have rejected blank book title")
        } catch DataTransferError.missingRequiredFields {
            // Expected
        } catch {
            assertionFailure("Unexpected error type: \(error)")
        }
    }
}

