//
//  StreakCalculationServiceTests.swift
//  BookStrideTests
//
//  Unit tests for reading habit streaks, in-progress day handling, and longest streaks.
//

import Foundation

public enum StreakCalculationServiceTests {
    public static func runAllTests() {
        print("▶ Running StreakCalculationServiceTests...")
        testSingleDayMeetingGoal()
        testTodayInProgressPreservesYesterdayStreak()
        testTodayMeetingGoalIncrementsStreak()
        testBrokenStreakWhenYesterdayMissed()
        testLongestStreakAcrossHistoricalGaps()
        testUnnormalizedDatesInDailyTotals()
        testEmptyHistoryStreak()
        print("✅ StreakCalculationServiceTests passed successfully.\n")
    }
    
    private static func testSingleDayMeetingGoal() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        let dailyTotals: [Date: Int] = [
            today: 1800 // 30 mins
        ]
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: today,
            calendar: cal
        )
        
        assert(streak.currentStreak == 1, "Single day meeting goal should have streak = 1, got \(streak.currentStreak)")
        assert(streak.isTodayCompleted == true, "Today should be completed")
        assert(streak.longestStreak == 1, "Longest streak should be 1")
    }
    
    private static func testTodayInProgressPreservesYesterdayStreak() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        
        // Yesterday and two days ago met goal, but today has only read 10 minutes so far
        let dailyTotals: [Date: Int] = [
            twoDaysAgo: 2400,
            yesterday: 1900,
            today: 600 // 10 min < 30 min goal
        ]
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: today,
            calendar: cal
        )
        
        // Streak from yesterday (2 days) must be preserved while today is underway!
        assert(streak.currentStreak == 2, "Current streak should remain 2 while today is in progress, got \(streak.currentStreak)")
        assert(streak.isTodayCompleted == false, "Today should not be completed yet")
    }
    
    private static func testTodayMeetingGoalIncrementsStreak() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        
        let dailyTotals: [Date: Int] = [
            twoDaysAgo: 2000,
            yesterday: 2000,
            today: 1850 // Reached 30m goal today!
        ]
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: today,
            calendar: cal
        )
        
        assert(streak.currentStreak == 3, "Streak should increment to 3 once today reaches goal, got \(streak.currentStreak)")
        assert(streak.isTodayCompleted == true, "Today should be completed")
    }
    
    private static func testBrokenStreakWhenYesterdayMissed() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: today)!
        
        // Active reading 3 days ago, but missed yesterday and day before
        let dailyTotals: [Date: Int] = [
            threeDaysAgo: 3600,
            today: 300 // In progress
        ]
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: today,
            calendar: cal
        )
        
        assert(streak.currentStreak == 0, "Current streak should be 0 since yesterday was missed and today not done, got \(streak.currentStreak)")
    }
    
    private static func testLongestStreakAcrossHistoricalGaps() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let base = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        
        // 5 consecutive days in past (days -20 to -16)
        var dailyTotals: [Date: Int] = [:]
        for offset in 16...20 {
            let day = cal.date(byAdding: .day, value: -offset, to: base)!
            dailyTotals[day] = 2000
        }
        
        // Current 2 days (yesterday and today)
        let yesterday = cal.date(byAdding: .day, value: -1, to: base)!
        dailyTotals[yesterday] = 2000
        dailyTotals[base] = 2000
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: base,
            calendar: cal
        )
        
        assert(streak.currentStreak == 2, "Current streak should be 2")
        assert(streak.longestStreak == 5, "Longest streak should be 5, got \(streak.longestStreak)")
    }
    
    private static func testUnnormalizedDatesInDailyTotals() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let base = cal.startOfDay(for: Date(timeIntervalSince1970: 1600000000))
        // Pass un-normalized dates (e.g. 14:35:22 and 21:10:45)
        let unnormYesterday = cal.date(byAdding: .day, value: -1, to: base)!.addingTimeInterval(52522)
        let unnormToday = base.addingTimeInterval(76245)
        
        let dailyTotals: [Date: Int] = [
            unnormYesterday: 2400,
            unnormToday: 2100
        ]
        
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: dailyTotals,
            dailyGoalMinutes: 30,
            today: base,
            calendar: cal
        )
        
        assert(streak.currentStreak == 2, "Streak calculation must safely normalize dates and return 2, got \(streak.currentStreak)")
        assert(streak.isTodayCompleted == true, "Today should be completed")
    }
    
    private static func testEmptyHistoryStreak() {
        let streak = StreakCalculationService.calculateStreak(
            dailyTotals: [:],
            dailyGoalMinutes: 30
        )
        assert(streak.currentStreak == 0, "Empty history must have streak 0")
        assert(streak.longestStreak == 0, "Empty history must have longest streak 0")
        assert(!streak.isTodayCompleted, "Empty history should not have today completed")
    }
}

