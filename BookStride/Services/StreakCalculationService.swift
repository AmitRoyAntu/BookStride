//
//  StreakCalculationService.swift
//  BookStride
//
//  Accurate streak calculation respecting daily goals and in-progress days.
//

import Foundation

public struct StreakInfo: Equatable {
    public let currentStreak: Int
    public let longestStreak: Int
    public let isTodayCompleted: Bool
    public let todayActiveSeconds: Int
    public let dailyGoalSeconds: Int
    
    public init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        isTodayCompleted: Bool = false,
        todayActiveSeconds: Int = 0,
        dailyGoalSeconds: Int = 1800
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.isTodayCompleted = isTodayCompleted
        self.todayActiveSeconds = todayActiveSeconds
        self.dailyGoalSeconds = dailyGoalSeconds
    }
}

public enum StreakCalculationService {
    
    /// Calculates streak information given daily active reading seconds and daily goal.
    /// `dailyTotals` dictionary is safely normalized to start of day in the provided calendar.
    public static func calculateStreak(
        dailyTotals: [Date: Int],
        dailyGoalMinutes: Int,
        today: Date = Date(),
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> StreakInfo {
        let goalSeconds = max(60, dailyGoalMinutes * 60)
        let normalizedToday = DateUtilities.startOfDay(for: today, calendar: calendar)
        
        // Defensively normalize all dailyTotals keys to startOfDay
        var normalizedTotals: [Date: Int] = [:]
        for (day, total) in dailyTotals {
            let normDay = DateUtilities.startOfDay(for: day, calendar: calendar)
            normalizedTotals[normDay, default: 0] += total
        }
        
        let todaySeconds = normalizedTotals[normalizedToday] ?? 0
        let todayCompleted = todaySeconds >= goalSeconds
        
        // Build set of days that met or exceeded the daily goal
        var qualifyingDays = Set<Date>()
        for (day, total) in normalizedTotals {
            if total >= goalSeconds {
                qualifyingDays.insert(day)
            }
        }
        
        // 1. Calculate current streak
        let currentStreak: Int
        if todayCompleted {
            // Today counts as 1 + consecutive preceding days
            var streak = 1
            var checkDay = DateUtilities.dateByAdding(days: -1, to: normalizedToday, calendar: calendar)
            while qualifyingDays.contains(checkDay) {
                streak += 1
                checkDay = DateUtilities.dateByAdding(days: -1, to: checkDay, calendar: calendar)
            }
            currentStreak = streak
        } else {
            // Today is still in progress! Check if yesterday was qualified.
            let yesterday = DateUtilities.dateByAdding(days: -1, to: normalizedToday, calendar: calendar)
            if qualifyingDays.contains(yesterday) {
                // Active streak from yesterday remains preserved while today is underway
                var streak = 1
                var checkDay = DateUtilities.dateByAdding(days: -1, to: yesterday, calendar: calendar)
                while qualifyingDays.contains(checkDay) {
                    streak += 1
                    checkDay = DateUtilities.dateByAdding(days: -1, to: checkDay, calendar: calendar)
                }
                currentStreak = streak
            } else {
                // Yesterday was not completed and today not completed yet
                currentStreak = 0
            }
        }
        
        // 2. Calculate longest streak across all history
        let sortedDays = qualifyingDays.sorted()
        var longestStreak = 0
        var currentRun = 0
        var previousDay: Date?
        
        for day in sortedDays {
            if let prev = previousDay {
                let diff = DateUtilities.daysBetween(start: prev, end: day, calendar: calendar)
                if diff == 1 {
                    currentRun += 1
                } else {
                    currentRun = 1
                }
            } else {
                currentRun = 1
            }
            longestStreak = max(longestStreak, currentRun)
            previousDay = day
        }
        
        // Longest streak should also never be less than current streak
        longestStreak = max(longestStreak, currentStreak)
        
        return StreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            isTodayCompleted: todayCompleted,
            todayActiveSeconds: todaySeconds,
            dailyGoalSeconds: goalSeconds
        )
    }
}

