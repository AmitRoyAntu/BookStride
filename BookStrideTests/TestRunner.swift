//
//  TestRunner.swift
//  BookStrideTests
//
//  Main test runner executing all unit tests for the BookStride reading companion app.
//

import Foundation

@main
struct TestRunner {
    static func main() {
        print("==================================================")
        print("📖 BookStride Core Engine Unit Test Suite")
        print("==================================================\n")
        
        let startTime = Date()
        
        ReadingTimerServiceTests.runAllTests()
        StreakCalculationServiceTests.runAllTests()
        ReadingStatisticsServiceTests.runAllTests()
        DataExportServiceTests.runAllTests()
        ValidationTests.runAllTests()
        Phase2FeatureTests.runAllTests()
        PolishReleaseTests.runAllTests()
        ReadingWrappedServiceTests.runAll()
        WidgetTimerServiceTests.runAll()
        AppleBooksAndImportTests.runAllTests()
        
        let elapsed = Date().timeIntervalSince(startTime)
        let formattedTime = String(format: "%.3f", elapsed)
        
        print("==================================================")
        print("🎉 ALL TEST SUITES PASSED in \(formattedTime)s")
        print("==================================================")
    }
}

