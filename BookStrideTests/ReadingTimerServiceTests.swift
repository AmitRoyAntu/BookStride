//
//  ReadingTimerServiceTests.swift
//  BookStrideTests
//
//  Unit tests for timer start, pause, resume, finish, duplicate session prevention, and restoration.
//

import Foundation

public enum ReadingTimerServiceTests {
    public static func runAllTests() {
        print("▶ Running ReadingTimerServiceTests...")
        testStartAndElapsedCalculation()
        testPreventDuplicateSessions()
        testPauseAndResumeWithPausedDuration()
        testFinishSessionAndClearState()
        testSessionRestoration()
        testStaleSessionResolution()
        testCrossMidnightSplitting()
        testExactMidnightBoundary()
        testMultiDayMidnightSplitting()
        print("✅ ReadingTimerServiceTests passed successfully.\n")
    }
    
    private static func testStartAndElapsedCalculation() {
        let defaultsSuite = "test_timer_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let start = Date(timeIntervalSince1970: 10000)
        let success = service.startSession(bookId: UUID(), bookTitle: "Test Book", startPage: 10, now: start)
        assert(success, "Timer should start successfully")
        assert(service.isRunning, "Service should be running")
        assert(!service.isPaused, "Service should not be paused")
        
        // Advance 120 seconds
        let current = start.addingTimeInterval(120)
        service.recalculateElapsed(now: current)
        assert(service.currentElapsedSeconds == 120, "Elapsed seconds should be 120, got \(service.currentElapsedSeconds)")
    }
    
    private static func testPreventDuplicateSessions() {
        let defaultsSuite = "test_timer_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let success1 = service.startSession(bookId: UUID(), bookTitle: "Book 1")
        assert(success1, "First session must start successfully")
        
        let success2 = service.startSession(bookId: UUID(), bookTitle: "Book 2")
        assert(!success2, "Second concurrent session must be rejected to prevent duplicate sessions")
    }
    
    private static func testPauseAndResumeWithPausedDuration() {
        let defaultsSuite = "test_timer_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let t0 = Date(timeIntervalSince1970: 1000)
        service.startSession(bookId: nil, bookTitle: "Unassigned", now: t0)
        
        // Run for 300 seconds (5 mins)
        let t1 = t0.addingTimeInterval(300)
        service.pauseSession(now: t1)
        assert(service.isPaused, "Session should be paused")
        assert(!service.isRunning, "Session should not be running")
        assert(service.currentElapsedSeconds == 300, "Active seconds should be 300")
        
        // Paused for 180 seconds (3 mins)
        let t2 = t1.addingTimeInterval(180)
        service.resumeSession(now: t2)
        assert(!service.isPaused, "Session should be resumed")
        assert(service.isRunning, "Session should be running")
        assert(service.activeState?.pausedDurationSeconds == 180, "Paused duration should be recorded as 180s")
        
        // Run for another 120 seconds
        let t3 = t2.addingTimeInterval(120)
        service.recalculateElapsed(now: t3)
        // Total active time should be 300 + 120 = 420 seconds (excluding the 180s paused time!)
        assert(service.currentElapsedSeconds == 420, "Total active elapsed should be 420s, got \(service.currentElapsedSeconds)")
    }
    
    private static func testFinishSessionAndClearState() {
        let defaultsSuite = "test_timer_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let t0 = Date(timeIntervalSince1970: 2000)
        service.startSession(bookId: UUID(), bookTitle: "Finishing Book", startPage: 50, now: t0)
        
        let t1 = t0.addingTimeInterval(600) // 10 minutes
        let snapshot = service.finishSession(endPage: 75, notes: "Great reading", now: t1)
        
        assert(snapshot != nil, "Snapshot should exist")
        assert(snapshot?.accumulatedActiveSeconds == 600, "Active seconds should be 600")
        assert(snapshot?.startPage == 50, "Start page should be 50")
        assert(snapshot?.endPage == 75, "End page should be 75")
        assert(snapshot?.notes == "Great reading", "Notes should match")
        assert(!service.isRunning, "Service should not be running after finish")
        assert(service.activeState == nil, "Active state should be cleared")
    }
    
    private static func testSessionRestoration() {
        let defaultsSuite = "test_timer_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        
        let bookId = UUID()
        let t0 = Date().addingTimeInterval(-120) // Started 2 minutes ago (well within 4-hour threshold)
        
        // Launch 1: start timer
        do {
            let service1 = ReadingTimerService(userDefaults: defaults)
            service1.startSession(bookId: bookId, bookTitle: "Persisted Book", startPage: 1, now: t0)
        }
        
        // Launch 2 (simulating normal app relaunch within active window)
        do {
            let service2 = ReadingTimerService(userDefaults: defaults)
            assert(service2.activeState != nil, "Active session state should be restored from storage")
            assert(service2.activeState?.bookId == bookId, "Book ID should match")
            assert(service2.activeState?.bookTitle == "Persisted Book", "Book title should match")
            assert(service2.isRunning, "Session should resume in running state")
            assert(!service2.showStaleSessionAlert, "Recent session should not trigger stale alert")
        }
        
        // Launch 3: test stale session detection when elapsed > 4 hours
        let staleDefaultsSuite = "test_stale_suite_\(UUID().uuidString)"
        let staleDefaults = UserDefaults(suiteName: staleDefaultsSuite)!
        let tStale = Date().addingTimeInterval(-18000) // 5 hours ago (> 4 hours threshold)
        
        do {
            let serviceStale1 = ReadingTimerService(userDefaults: staleDefaults)
            serviceStale1.startSession(bookId: bookId, bookTitle: "Stale Book", startPage: 1, now: tStale)
        }
        
        do {
            let serviceStale2 = ReadingTimerService(userDefaults: staleDefaults)
            assert(serviceStale2.showStaleSessionAlert == true, "Stale session should trigger review alert")
            assert(serviceStale2.isPaused == true, "Stale session should be paused pending user review")
        }
    }
    
    private static func testStaleSessionResolution() {
        let defaultsSuite = "test_stale_res_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let tStale = Date().addingTimeInterval(-20000) // 5.5 hours ago
        service.startSession(bookId: UUID(), bookTitle: "Stale", now: tStale)
        
        // Simulate relaunch detecting stale session
        service.restoreActiveSession()
        assert(service.showStaleSessionAlert == true, "Should flag stale session")
        
        // Resolve with custom 45 minutes (2700s)
        service.resolveStaleSession(action: .customDuration, customMinutes: 45)
        assert(!service.showStaleSessionAlert, "Alert should be dismissed")
        assert(service.isPaused, "Session should be safely paused")
        assert(service.currentElapsedSeconds == 2700, "Elapsed should match 45 mins (2700s), got \(service.currentElapsedSeconds)")
        
        // Now finish session
        let snapshot = service.finishSession()
        assert(snapshot?.accumulatedActiveSeconds == 2700, "Snapshot should preserve resolved duration")
    }
    
    private static func testCrossMidnightSplitting() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // 2026-10-28 23:30:00 UTC
        let compStart = DateComponents(calendar: cal, timeZone: cal.timeZone, year: 2026, month: 10, day: 28, hour: 23, minute: 30, second: 0)
        let startDate = cal.date(from: compStart)!
        
        // 2026-10-29 00:30:00 UTC (Total: 60 mins = 3600 seconds)
        let endDate = startDate.addingTimeInterval(3600)
        
        let allocations = DateUtilities.splitSessionAcrossDays(
            startedAt: startDate,
            endedAt: endDate,
            activeSeconds: 3600,
            calendar: cal
        )
        
        assert(allocations.count == 2, "Session crossing midnight must be split into exactly 2 days")
        assert(allocations[0].activeSeconds == 1800, "Day 1 should receive 1800 active seconds")
        assert(allocations[1].activeSeconds == 1800, "Day 2 should receive 1800 active seconds")
        assert(allocations.reduce(0) { $0 + $1.activeSeconds } == 3600, "Sum of daily allocations must equal active seconds")
    }
    
    private static func testExactMidnightBoundary() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // Starts 23:30, ends exactly at midnight 00:00:00
        let compStart = DateComponents(calendar: cal, timeZone: cal.timeZone, year: 2026, month: 10, day: 28, hour: 23, minute: 30, second: 0)
        let startDate = cal.date(from: compStart)!
        let compEnd = DateComponents(calendar: cal, timeZone: cal.timeZone, year: 2026, month: 10, day: 29, hour: 0, minute: 0, second: 0)
        let endDate = cal.date(from: compEnd)!
        
        let allocations = DateUtilities.splitSessionAcrossDays(
            startedAt: startDate,
            endedAt: endDate,
            activeSeconds: 1800,
            calendar: cal
        )
        
        assert(allocations.count == 1, "Session ending exactly at midnight should only allocate to day 1, got \(allocations.count)")
        assert(allocations[0].activeSeconds == 1800, "All 1800 active seconds should belong to day 1")
    }
    
    private static func testMultiDayMidnightSplitting() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        // Spans across 3 calendar days (Day 1: 2 hours, Day 2: 24 hours, Day 3: 2 hours = 28 hours)
        let compStart = DateComponents(calendar: cal, timeZone: cal.timeZone, year: 2026, month: 10, day: 20, hour: 22, minute: 0, second: 0)
        let startDate = cal.date(from: compStart)!
        let compEnd = DateComponents(calendar: cal, timeZone: cal.timeZone, year: 2026, month: 10, day: 22, hour: 2, minute: 0, second: 0)
        let endDate = cal.date(from: compEnd)!
        
        let activeSeconds = 28 * 3600
        let allocations = DateUtilities.splitSessionAcrossDays(
            startedAt: startDate,
            endedAt: endDate,
            activeSeconds: activeSeconds,
            calendar: cal
        )
        
        assert(allocations.count == 3, "Session spanning 3 calendar days must split into 3 allocations")
        assert(allocations.reduce(0) { $0 + $1.activeSeconds } == activeSeconds, "Total allocated seconds must sum exactly to activeSeconds")
        assert(allocations[0].activeSeconds == 2 * 3600, "Day 1 should have 2 hours")
        assert(allocations[1].activeSeconds == 24 * 3600, "Day 2 should have 24 hours")
        assert(allocations[2].activeSeconds == 2 * 3600, "Day 3 should have 2 hours")
    }
}
