//
//  QuoteCardTests.swift
//  BookStrideTests
//
//  Unit tests verifying QuoteCardTheme, QuoteCardFont, QuoteCardAspectRatio,
//  and QuoteCardConfig layout dimensions.
//

import Foundation
import SwiftUI

public enum QuoteCardTests {
    public static func runAllTests() {
        print("▶ Running QuoteCardTests (Aesthetic Quote Cards)...")
        testThemesAndColors()
        testFontDesigns()
        testAspectRatiosAndDimensions()
        testConfigDefaults()
        print("✅ QuoteCardTests passed successfully.\n")
    }
    
    private static func testThemesAndColors() {
        let themes = QuoteCardTheme.allCases
        assert(themes.count == 5, "Should have 5 curated aesthetic themes")
        
        for theme in themes {
            assert(!theme.rawValue.isEmpty, "Theme name must not be empty")
            _ = theme.backgroundColor
            _ = theme.primaryTextColor
            _ = theme.secondaryTextColor
            _ = theme.accentColor
            _ = theme.borderColor
        }
    }
    
    private static func testFontDesigns() {
        let fonts = QuoteCardFont.allCases
        assert(fonts.count == 4, "Should have 4 typographic styles")
        
        for font in fonts {
            assert(!font.rawValue.isEmpty, "Font name must not be empty")
            _ = font.fontDesign
        }
    }
    
    private static func testAspectRatiosAndDimensions() {
        assert(QuoteCardAspectRatio.square.ratio == 1.0, "Square aspect ratio must be 1.0")
        assert(QuoteCardAspectRatio.portrait.ratio == 0.8, "Portrait aspect ratio must be 4:5 (0.8)")
        assert(QuoteCardAspectRatio.story.ratio == (9.0 / 16.0), "Story aspect ratio must be 9:16")
        
        // Export dimensions
        assert(QuoteCardAspectRatio.square.exportSize.width == 1080 && QuoteCardAspectRatio.square.exportSize.height == 1080)
        assert(QuoteCardAspectRatio.portrait.exportSize.width == 1080 && QuoteCardAspectRatio.portrait.exportSize.height == 1350)
        assert(QuoteCardAspectRatio.story.exportSize.width == 1080 && QuoteCardAspectRatio.story.exportSize.height == 1920)
        
        // Preview dimensions
        assert(QuoteCardAspectRatio.square.previewSize.width > 0 && QuoteCardAspectRatio.square.previewSize.height > 0)
    }
    
    private static func testConfigDefaults() {
        let config = QuoteCardConfig()
        assert(config.theme == .linenCream, "Default theme should be linenCream")
        assert(config.fontStyle == .literarySerif, "Default font should be literarySerif")
        assert(config.aspectRatio == .square, "Default aspect ratio should be square")
        assert(config.showBookTitle == true, "Book title should be visible by default")
        assert(config.showAuthor == true, "Author should be visible by default")
        assert(config.showQuotationMarks == true, "Quotation marks should be visible by default")
    }
}

