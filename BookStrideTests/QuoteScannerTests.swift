//
//  QuoteScannerTests.swift
//  BookStrideTests
//
//  Unit tests verifying optical character recognition (OCR) text cleaning,
//  hyphen line-break joining, and header/footer page number parsing.
//

import Foundation

public struct QuoteScannerTests {
    public static func runAll() {
        print("\n▶ Running QuoteScannerTests (OCR Text Processing)...")
        testPageNumberParsing()
        testLineCleaningAndHyphenJoining()
        testHeaderAndFooterPageExtraction()
        print("✅ QuoteScannerTests passed successfully.")
    }
    
    private static func testPageNumberParsing() {
        assert(QuoteTextProcessor.parsePageNumber(from: "142") == 142)
        assert(QuoteTextProcessor.parsePageNumber(from: "Page 95") == 95)
        assert(QuoteTextProcessor.parsePageNumber(from: "p. 310") == 310)
        assert(QuoteTextProcessor.parsePageNumber(from: "- 17 -") == 17)
        assert(QuoteTextProcessor.parsePageNumber(from: "• 88 •") == 88)
        assert(QuoteTextProcessor.parsePageNumber(from: "Not a number") == nil)
    }
    
    private static func testLineCleaningAndHyphenJoining() {
        let rawLines = [
            "This is an un-",
            "forgettable experience in literature."
        ]
        let (cleaned, page) = QuoteTextProcessor.cleanExtractedLines(rawLines)
        assert(cleaned == "This is an unforgettable experience in literature.", "Hyphenated line was not joined correctly: '\(cleaned)'")
        assert(page == nil, "Page should be nil")
    }
    
    private static func testHeaderAndFooterPageExtraction() {
        // Page footer
        let lines = [
            "Call me Ishmael.",
            "Some years ago--never mind how long precisely.",
            "Page 1"
        ]
        let (cleaned, page) = QuoteTextProcessor.cleanExtractedLines(lines)
        assert(page == 1, "Expected page 1, got \(String(describing: page))")
        assert(cleaned.contains("Call me Ishmael."), "Cleaned text missing body")
        
        // Header page number
        let linesWithHeader = [
            "- 42 -",
            "It was a bright cold day in April, and the clocks were striking thirteen."
        ]
        let (cleanedH, pageH) = QuoteTextProcessor.cleanExtractedLines(linesWithHeader)
        assert(pageH == 42, "Expected page 42, got \(String(describing: pageH))")
        assert(cleanedH.contains("It was a bright cold day in April"), "Cleaned text missing body")
    }
}
