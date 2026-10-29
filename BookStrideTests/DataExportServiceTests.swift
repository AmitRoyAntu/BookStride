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
        testTolerantDateDecoding()
        testMissingFieldsResilience()
        testCSVExportFormatting()
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
    
    private static func testTolerantDateDecoding() {
        // Test JSON with ISO8601 millisecond timestamp, timezone offset, and epoch seconds
        let jsonPayload = """
        {
            "schemaVersion": 1,
            "appVersion": "1.0.0",
            "exportedAt": "2026-10-30T03:58:12.345Z",
            "books": [
                {
                    "id": "11111111-1111-1111-1111-111111111111",
                    "title": "Atomic Habits",
                    "createdAt": "2026-10-30T03:58:12+06:00",
                    "updatedAt": "2026-10-30"
                }
            ],
            "sessions": [
                {
                    "id": "22222222-2222-2222-2222-222222222222",
                    "startedAt": 1730260692.0,
                    "accumulatedActiveSeconds": 1200
                }
            ],
            "journalEntries": []
        }
        """
        
        guard let data = jsonPayload.data(using: .utf8) else {
            assertionFailure("Failed to create test data")
            return
        }
        
        do {
            let parsed = try DataExportService.parseAndValidateJSON(data)
            assert(parsed.books.count == 1, "Should parse book with fractional date")
            assert(parsed.books[0].title == "Atomic Habits", "Book title should match")
            assert(parsed.sessions.count == 1, "Should parse session with epoch timestamp")
            assert(parsed.sessions[0].accumulatedActiveSeconds == 1200, "Active seconds should match")
        } catch {
            assertionFailure("Tolerant date decoding failed: \(error)")
        }
    }
    
    private static func testMissingFieldsResilience() {
        // Test package where optional or newly added fields are missing entirely
        let jsonPayload = """
        {
            "books": [
                {
                    "title": "Deep Work"
                }
            ],
            "sessions": [
                {
                    "startedAt": "2026-10-30T03:00:00Z"
                }
            ],
            "journalEntries": [
                {
                    "content": "Key takeaway on deep focus."
                }
            ]
        }
        """
        
        guard let data = jsonPayload.data(using: .utf8) else {
            assertionFailure("Failed to create test data")
            return
        }
        
        do {
            let parsed = try DataExportService.parseAndValidateJSON(data)
            assert(parsed.books.count == 1, "Should parse book missing id/author/cover")
            assert(parsed.books[0].author == "", "Default author should be empty string")
            assert(parsed.books[0].coverColorHex == "forest", "Default coverColorHex should be forest")
            assert(parsed.sessions.count == 1, "Should parse session missing id/activeSeconds")
            assert(parsed.sessions[0].status == "Completed", "Default status should be Completed")
            assert(parsed.journalEntries.count == 1, "Should parse journal entry missing isFavorite")
            assert(!parsed.journalEntries[0].isFavorite, "Default isFavorite should be false")
        } catch {
            assertionFailure("Missing fields resilience failed: \(error)")
        }
    }
    
    private static func testCSVExportFormatting() {
        let b1 = BookDTO(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Pride and Prejudice, and Zombies",
            author: "Jane Austen & \"Seth\" Grahame-Smith"
        )
        let s1 = ReadingSessionDTO(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            bookId: b1.id,
            startedAt: Date(timeIntervalSince1970: 1730000000),
            endedAt: Date(timeIntervalSince1970: 1730001800),
            accumulatedActiveSeconds: 1800,
            notes: "Chapter 1,\nChapter 2"
        )
        let j1 = JournalEntryDTO(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            bookId: b1.id,
            content: "Quote: \"To be, or not to be, that is the question.\""
        )
        
        let booksCSV = DataExportService.exportBooksToCSV(bookDTOs: [b1])
        assert(booksCSV.contains("\"Pride and Prejudice, and Zombies\""), "Comma in title must be escaped")
        assert(booksCSV.contains("\"Jane Austen & \"\"Seth\"\" Grahame-Smith\""), "Quotes in author must be escaped")
        
        let sessionsCSV = DataExportService.exportSessionsToCSV(sessionDTOs: [s1], bookTitles: [b1.id: b1.title])
        assert(sessionsCSV.contains("\"Chapter 1,\r\nChapter 2\"") || sessionsCSV.contains("\"Chapter 1,\nChapter 2\""), "Multiline notes must be escaped")
        
        let journalCSV = DataExportService.exportJournalToCSV(journalDTOs: [j1], bookTitles: [b1.id: b1.title])
        assert(journalCSV.contains("\"Quote: \"\"To be, or not to be, that is the question.\"\"\""), "Quotes in note content must be escaped")
    }
}

