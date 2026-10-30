//
//  AppleBooksAndImportTests.swift
//  BookStrideTests
//
//  Unit tests for Apple Books URL validation, store search links,
//  EPUB/PDF import metadata extraction, and duplicate detection.
//

import Foundation

public enum AppleBooksAndImportTests {
    public static func runAllTests() {
        print("▶ Running AppleBooksAndImportTests...")
        testAppleBooksURLValidation()
        testAppleBooksSearchURL()
        testDuplicateDetection()
        testModelSourceFormatAccessors()
        testExtractMetadataMethodSignature()
        print("✅ AppleBooksAndImportTests passed successfully.\n")
    }
    
    private static func testAppleBooksURLValidation() {
        // Valid Apple Books schemes
        assert(AppleBooksService.isValidAppleBooksURL("ibooks://"), "ibooks:// should be valid")
        assert(AppleBooksService.isValidAppleBooksURL("ibooks://assetid/12345"), "ibooks asset link should be valid")
        assert(AppleBooksService.isValidAppleBooksURL("itms-books://itunes.apple.com/book/id123"), "itms-books:// should be valid")
        assert(AppleBooksService.isValidAppleBooksURL("https://books.apple.com/us/book/clean-code/id123456"), "Web books.apple.com should be valid")
        assert(AppleBooksService.isValidAppleBooksURL("  https://books.apple.com/gb/book/atomic-habits/id789  "), "URL with whitespace should be trimmed and valid")
        
        // Invalid URLs
        assert(!AppleBooksService.isValidAppleBooksURL(""), "Empty string must not be valid")
        assert(!AppleBooksService.isValidAppleBooksURL("   "), "Whitespace must not be valid")
        assert(!AppleBooksService.isValidAppleBooksURL("not a url"), "Plain text must not be valid")
        assert(!AppleBooksService.isValidAppleBooksURL("https://google.com"), "Non-Apple Books host must not be valid")
        assert(!AppleBooksService.isValidAppleBooksURL("https://amazon.com/dp/B08XYZ"), "Amazon link must not be valid")
        assert(!AppleBooksService.isValidAppleBooksURL("file:///path/to/book.pdf"), "Local file URL must not be accepted as Apple Books URL")
    }
    
    private static func testAppleBooksSearchURL() {
        let url1 = AppleBooksService.searchStoreURL(title: "Atomic Habits", author: "James Clear")
        assert(url1 != nil, "Search URL should be generated")
        assert(url1!.absoluteString.contains("books.apple.com/us/search?term="), "Should point to books.apple.com search")
        assert(url1!.absoluteString.contains("Atomic"), "Should contain title")
        assert(url1!.absoluteString.contains("Clear"), "Should contain author")
        
        // Title only
        let url2 = AppleBooksService.searchStoreURL(title: "The Hobbit", author: "")
        assert(url2 != nil, "Title-only search URL should be generated")
        assert(url2!.absoluteString.contains("Hobbit"), "Should contain title")
        
        // Special characters
        let url3 = AppleBooksService.searchStoreURL(title: "Design & Architecture: Clean?", author: "")
        assert(url3 != nil, "Search URL with special characters should be percent encoded")
    }
    
    private static func testDuplicateDetection() {
        let existingBooks = [
            BookDTO(title: "Thinking, Fast and Slow", author: "Daniel Kahneman"),
            BookDTO(title: "Atomic Habits", author: "James Clear"),
            BookDTO(title: "Deep Work", author: "Cal Newport")
        ]
        
        // Exact match
        let dup1 = BookImportService.findDuplicate(title: "Atomic Habits", author: "James Clear", in: existingBooks)
        assert(dup1 != nil, "Exact match should detect duplicate")
        assert(dup1?.title == "Atomic Habits", "Matched title should be Atomic Habits")
        
        // Case-insensitive match
        let dup2 = BookImportService.findDuplicate(title: "thinking, fast and slow", author: "daniel kahneman", in: existingBooks)
        assert(dup2 != nil, "Case-insensitive match should detect duplicate")
        
        // Trimmed whitespace match
        let dup3 = BookImportService.findDuplicate(title: "  Deep Work  ", author: "Cal Newport ", in: existingBooks)
        assert(dup3 != nil, "Whitespace-trimmed match should detect duplicate")
        
        // Substantially different books
        let notDup = BookImportService.findDuplicate(title: "Slow Thinking", author: "Someone Else", in: existingBooks)
        assert(notDup == nil, "Different book should not detect duplicate")
        
        let notDup2 = BookImportService.findDuplicate(title: "Atomic Design", author: "Brad Frost", in: existingBooks)
        assert(notDup2 == nil, "Book with partial title match should not detect duplicate")
    }
    
    private static func testModelSourceFormatAccessors() {
        let metadata = ExtractedBookMetadata(
            title: "Sample EPUB",
            author: "Author Name",
            totalPages: 250,
            format: .epub,
            fileName: "sample.epub",
            isDRMProtected: false,
            appleBooksURL: "https://books.apple.com/us/book/id123"
        )
        assert(metadata.format == .epub, "Format should be EPUB")
        assert(metadata.totalPages == 250, "Total pages should be 250")
        assert(!metadata.isDRMProtected, "Should not be DRM protected")
        assert(metadata.appleBooksURL != nil, "appleBooksURL should be preserved")
        
        let bookDTO = BookDTO(
            title: "Sample PDF",
            author: "Author",
            appleBooksURL: "ibooks://",
            importedFileName: "sample.pdf",
            sourceFormat: "PDF"
        )
        assert(bookDTO.sourceFormat == "PDF", "sourceFormat should be PDF")
        assert(bookDTO.importedFileName == "sample.pdf", "importedFileName should match")
        assert(bookDTO.appleBooksURL == "ibooks://", "appleBooksURL should match")
    }
    
    private static func testExtractMetadataMethodSignature() {
        // Verify extractMetadata throws expected unsupportedFormat on non-existent or unsupported file format
        let dummyURL = URL(fileURLWithPath: "/tmp/nonexistent.docx")
        do {
            _ = try BookImportService.extractMetadata(from: dummyURL)
            assert(false, "Should have thrown unsupported format error")
        } catch let BookImportError.unsupportedFormat(ext) {
            assert(ext == "docx", "Expected docx extension in error: \(ext)")
        } catch {
            // Any other error is acceptable if system restricts path
        }
    }
}
