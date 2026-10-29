//
//  DateUtilities.swift
//  BookStride
//
//  Calendar, interval, cross-midnight split, and date calculation utilities.
//

import Foundation

public struct DailyTimeAllocation: Equatable {
    public let date: Date // Normalized to start of day
    public let activeSeconds: Int
    
    public init(date: Date, activeSeconds: Int) {
        self.date = date
        self.activeSeconds = activeSeconds
    }
}

public enum DateUtilities {
    public static var defaultCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        return cal
    }
    
    /// Normalizes a date to 00:00:00 in the given calendar.
    public static func startOfDay(for date: Date, calendar: Calendar = defaultCalendar) -> Date {
        calendar.startOfDay(for: date)
    }
    
    /// Returns the end of day (23:59:59.999) for the given date.
    public static func endOfDay(for date: Date, calendar: Calendar = defaultCalendar) -> Date {
        let start = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: start) else {
            return date
        }
        return nextDay.addingTimeInterval(-0.001)
    }
    
    /// Returns true if two dates are in the same calendar day.
    public static func isSameDay(_ date1: Date, _ date2: Date, calendar: Calendar = defaultCalendar) -> Bool {
        calendar.isDate(date1, inSameDayAs: date2)
    }
    
    /// Returns true if the date is today.
    public static func isToday(_ date: Date, calendar: Calendar = defaultCalendar) -> Bool {
        calendar.isDateInToday(date)
    }
    
    /// Returns true if the date is yesterday.
    public static func isYesterday(_ date: Date, calendar: Calendar = defaultCalendar) -> Bool {
        calendar.isDateInYesterday(date)
    }
    
    /// Calculates the date by adding days.
    public static func dateByAdding(days: Int, to date: Date, calendar: Calendar = defaultCalendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
    
    /// Calculates the number of calendar days between two dates.
    public static func daysBetween(start: Date, end: Date, calendar: Calendar = defaultCalendar) -> Int {
        let s = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        let components = calendar.dateComponents([.day], from: s, to: e)
        return abs(components.day ?? 0)
    }
    
    /// Splits an active reading session across calendar midnights.
    /// Distributes active reading time proportionally across the calendar days spanned by the session,
    /// ensuring that paused time is completely excluded and daily allocations sum to exactly `activeSeconds`.
    public static func splitSessionAcrossDays(
        startedAt: Date,
        endedAt: Date,
        activeSeconds: Int,
        calendar: Calendar = defaultCalendar
    ) -> [DailyTimeAllocation] {
        guard activeSeconds > 0 else { return [] }
        
        let startDay = startOfDay(for: startedAt, calendar: calendar)
        
        // Defensive: ensure endedAt is at least startedAt + activeSeconds
        let effectiveEndedAt = max(endedAt, startedAt.addingTimeInterval(Double(activeSeconds)))
        let endDay = startOfDay(for: effectiveEndedAt, calendar: calendar)
        
        // Fast path: session occurred entirely within a single calendar day
        if startDay == endDay {
            return [DailyTimeAllocation(date: startDay, activeSeconds: activeSeconds)]
        }
        
        // Multi-day session: compute daily intervals
        var dayIntervals: [(day: Date, span: TimeInterval)] = []
        var currentDayStart = startDay
        let totalElapsedSpan = max(Double(activeSeconds), effectiveEndedAt.timeIntervalSince(startedAt))
        
        while currentDayStart <= endDay {
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: currentDayStart) else { break }
            let intervalStart = max(startedAt, currentDayStart)
            let intervalEnd = min(effectiveEndedAt, nextDayStart)
            
            let span = max(0, intervalEnd.timeIntervalSince(intervalStart))
            if span > 0 {
                dayIntervals.append((day: currentDayStart, span: span))
            }
            currentDayStart = nextDayStart
        }
        
        guard !dayIntervals.isEmpty, totalElapsedSpan > 0 else {
            return [DailyTimeAllocation(date: startDay, activeSeconds: activeSeconds)]
        }
        
        // Distribute active seconds proportionally based on elapsed span in each day
        var allocations: [DailyTimeAllocation] = []
        var remainingSeconds = activeSeconds
        
        for (index, item) in dayIntervals.enumerated() {
            let isLast = (index == dayIntervals.count - 1)
            let dayShare: Int
            
            if isLast {
                dayShare = remainingSeconds
            } else {
                let proportion = item.span / totalElapsedSpan
                let calculated = Int(round(Double(activeSeconds) * proportion))
                dayShare = min(remainingSeconds, max(0, calculated))
                remainingSeconds -= dayShare
            }
            
            if dayShare > 0 {
                allocations.append(DailyTimeAllocation(date: item.day, activeSeconds: dayShare))
            }
        }
        
        return allocations
    }
}

