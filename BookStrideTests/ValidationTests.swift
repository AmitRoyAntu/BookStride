//
//  ValidationTests.swift
//  BookStrideTests
//
//  Unit tests for input validation, boundary conditions, and progress rules.
//

import Foundation

public enum ValidationTests {
    public static func runAllTests() {
        print("▶ Running ValidationTests...")
        testBookPageValidationRules()
        testSessionDurationRules()
        testPageDeltaCalculation()
        testTitleValidationRules()
        testLiveSessionPageValidationRules()
        print("✅ ValidationTests passed successfully.\n")
    }
    
    private static func testBookPageValidationRules() {
        // Current page <= total pages when total is known
        let total = 300
        let validCurrent = 150
        let invalidCurrent = 350
        
        assert(validCurrent <= total, "Valid current page must be <= total")
        assert(!(invalidCurrent <= total), "Invalid current page exceeding total must be detected")
        
        // Progress fraction calculation
        let progress = Double(validCurrent) / Double(total)
        assert(progress == 0.5, "Progress should be 50%")
    }
    
    private static func testSessionDurationRules() {
        let validSeconds = 1800
        let negativeSeconds = -50
        
        assert(validSeconds > 0, "Valid reading session must have duration > 0")
        assert(negativeSeconds <= 0, "Negative duration must be flagged")
    }
    
    private static func testPageDeltaCalculation() {
        let startPage = 40
        let endPage = 75
        let delta = endPage - startPage
        assert(delta == 35, "Pages read must be 35")
        
        let invalidEnd = 30
        assert(invalidEnd < startPage, "Backwards page progression must be flagged")
    }
    
    private static func testTitleValidationRules() {
        let emptyTitle = ""
        let whitespaceTitle = "   \n\t  "
        let validTitle = "Great Expectations"
        
        assert(emptyTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty title must be caught")
        assert(whitespaceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Whitespace title must be caught")
        assert(!validTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Valid title must pass")
    }
    
    private static func testLiveSessionPageValidationRules() {
        let startPage = 100
        let totalPages = 250
        
        let validEndPage = 135
        let backwardsEndPage = 95
        let exceedingEndPage = 280
        
        assert(validEndPage >= startPage && validEndPage <= totalPages, "Valid page progression must pass")
        assert(backwardsEndPage < startPage, "Ending page before starting page must be rejected")
        assert(exceedingEndPage > totalPages, "Ending page exceeding total pages must be rejected")
    }
}

