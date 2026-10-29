//
//  ReadingStatisticsService.swift
//  BookStride
//
//  Analytics computation, time filtering, cross-midnight daily breakdown, and chart data modeling.
//

import Foundation

public enum TimeFilter: String, CaseIterable, Identifiable {
    case last7Days = "7 Days"
    case last30Days = "30 Days"
    case last90Days = "90 Days"
    case thisYear = "This Year"
    case allTime = "All Time"
    
    public var id: String { rawValue }
    
    public func startDate(relativeTo now: Date, calendar: Calendar) -> Date? {
        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .last30Days:
            return calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        case .last90Days:
            return calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
        case .thisYear:
            let comps = calendar.dateComponents([.year], from: now)
            return calendar.date(from: comps)
        case .allTime:
            return nil
        }
    }
}

public struct DailyReadingPoint: Identifiable, Equatable {
    public let id = UUID()
    public let date: Date
    public let minutes: Double
    public let metGoal: Bool
    public let isToday: Bool
    
    public init(date: Date, minutes: Double, metGoal: Bool, isToday: Bool) {
        self.date = date
        self.minutes = minutes
        self.metGoal = metGoal
        self.isToday = isToday
    }
}

public struct WeeklyReadingPoint: Identifiable, Equatable {
    public let id = UUID()
    public let weekStart: Date
    public let label: String
    public let minutes: Double
    
    public init(weekStart: Date, label: String, minutes: Double) {
        self.weekStart = weekStart
        self.label = label
        self.minutes = minutes
    }
}

public struct MonthlyReadingPoint: Identifiable, Equatable {
    public let id = UUID()
    public let monthDate: Date
    public let label: String
    public let hours: Double
    
    public init(monthDate: Date, label: String, hours: Double) {
        self.monthDate = monthDate
        self.label = label
        self.hours = hours
    }
}

public struct BookTimePoint: Identifiable, Equatable {
    public let id = UUID()
    public let bookId: UUID?
    public let title: String
    public let author: String
    public let coverColorHex: String
    public let minutes: Double
    public let percentage: Double
    
    public init(bookId: UUID?, title: String, author: String, coverColorHex: String, minutes: Double, percentage: Double) {
        self.bookId = bookId
        self.title = title
        self.author = author
        self.coverColorHex = coverColorHex
        self.minutes = minutes
        self.percentage = percentage
    }
}

public struct HeatmapDayPoint: Identifiable, Equatable {
    public let id = UUID()
    public let date: Date
    public let minutes: Int
    public let intensity: Int // 0 (none), 1 (light), 2 (medium), 3 (good), 4 (goal met)
    public let isCurrentMonth: Bool
    public let sessionCount: Int
    public let metGoal: Bool
    public let isToday: Bool
    
    public init(
        date: Date,
        minutes: Int,
        intensity: Int,
        isCurrentMonth: Bool = true,
        sessionCount: Int = 0,
        metGoal: Bool = false,
        isToday: Bool = false
    ) {
        self.date = date
        self.minutes = minutes
        self.intensity = intensity
        self.isCurrentMonth = isCurrentMonth
        self.sessionCount = sessionCount
        self.metGoal = metGoal
        self.isToday = isToday
    }
}

public struct InsightsAnalyticsSummary: Equatable {
    public let totalReadingSeconds: Int
    public let averageDailySeconds: Int
    public let averageSessionSeconds: Int
    public let totalSessionsCount: Int
    public let totalBooksFinishedCount: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let goalCompletionRate: Double
    public let totalPagesRead: Int
    public let readingSecondsToday: Int
    public let readingSecondsThisWeek: Int
    public let readingSecondsThisMonth: Int
    
    public init(
        totalReadingSeconds: Int = 0,
        averageDailySeconds: Int = 0,
        averageSessionSeconds: Int = 0,
        totalSessionsCount: Int = 0,
        totalBooksFinishedCount: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        goalCompletionRate: Double = 0.0,
        totalPagesRead: Int = 0,
        readingSecondsToday: Int = 0,
        readingSecondsThisWeek: Int = 0,
        readingSecondsThisMonth: Int = 0
    ) {
        self.totalReadingSeconds = totalReadingSeconds
        self.averageDailySeconds = averageDailySeconds
        self.averageSessionSeconds = averageSessionSeconds
        self.totalSessionsCount = totalSessionsCount
        self.totalBooksFinishedCount = totalBooksFinishedCount
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.goalCompletionRate = goalCompletionRate
        self.totalPagesRead = totalPagesRead
        self.readingSecondsToday = readingSecondsToday
        self.readingSecondsThisWeek = readingSecondsThisWeek
        self.readingSecondsThisMonth = readingSecondsThisMonth
    }
}

public enum ReadingStatisticsService {
    
    /// Computes full analytics for a given time filter.
    public static func computeAnalytics(
        sessions: [ReadingSessionDTO],
        books: [BookDTO],
        filter: TimeFilter,
        dailyGoalMinutes: Int = 30,
        now: Date = Date(),
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> (
        summary: InsightsAnalyticsSummary,
        dailyPoints: [DailyReadingPoint],
        weeklyTrend: [WeeklyReadingPoint],
        monthlyActivity: [MonthlyReadingPoint],
        bookDistribution: [BookTimePoint],
        heatmapPoints: [HeatmapDayPoint]
    ) {
        let goalSeconds = max(60, dailyGoalMinutes * 60)
        let filterStartDate = filter.startDate(relativeTo: now, calendar: calendar)
        
        // 1. Break down ALL completed sessions by calendar day (cross-midnight split)
        var allTimeDailyTotals: [Date: Int] = [:]
        var sessionCount = 0
        var totalPages = 0
        
        let completedSessions = sessions.filter { $0.status == SessionStatus.completed.rawValue }
        
        for session in completedSessions {
            let activeSecs = session.activeSeconds
            guard activeSecs > 0 else { continue }
            
            let ended = session.endedAt ?? session.startedAt.addingTimeInterval(Double(activeSecs))
            let allocations = DateUtilities.splitSessionAcrossDays(
                startedAt: session.startedAt,
                endedAt: ended,
                activeSeconds: activeSecs,
                calendar: calendar
            )
            
            for alloc in allocations {
                allTimeDailyTotals[alloc.date, default: 0] += alloc.activeSeconds
            }
        }
        
        // Compute streaks across all-time history
        let streakInfo = StreakCalculationService.calculateStreak(
            dailyTotals: allTimeDailyTotals,
            dailyGoalMinutes: dailyGoalMinutes,
            today: now,
            calendar: calendar
        )
        
        // 2. Filter sessions for the active time window
        let filteredSessions = completedSessions.filter { s in
            guard let startDate = filterStartDate else { return true }
            let sessionDate = s.startedAt
            return sessionDate >= startDate
        }
        
        var filteredDailyTotals: [Date: Int] = [:]
        for session in filteredSessions {
            sessionCount += 1
            if let start = session.startPage, let end = session.endPage, end >= start {
                totalPages += (end - start)
            }
            let activeSecs = session.activeSeconds
            let ended = session.endedAt ?? session.startedAt.addingTimeInterval(Double(activeSecs))
            let allocations = DateUtilities.splitSessionAcrossDays(
                startedAt: session.startedAt,
                endedAt: ended,
                activeSeconds: activeSecs,
                calendar: calendar
            )
            for alloc in allocations {
                if let filterStart = filterStartDate, alloc.date < filterStart { continue }
                filteredDailyTotals[alloc.date, default: 0] += alloc.activeSeconds
            }
        }
        
        let totalActiveSeconds = filteredSessions.reduce(0) { $0 + $1.activeSeconds }
        let avgSessionSeconds = sessionCount > 0 ? (totalActiveSeconds / sessionCount) : 0
        
        // Calculate number of elapsed days in filter window
        let totalDaysInWindow: Int
        if let filterStart = filterStartDate {
            totalDaysInWindow = max(1, DateUtilities.daysBetween(start: filterStart, end: now, calendar: calendar) + 1)
        } else {
            // All time
            if let earliest = allTimeDailyTotals.keys.min() {
                totalDaysInWindow = max(1, DateUtilities.daysBetween(start: earliest, end: now, calendar: calendar) + 1)
            } else {
                totalDaysInWindow = 1
            }
        }
        
        let avgDailySeconds = totalDaysInWindow > 0 ? (totalActiveSeconds / totalDaysInWindow) : 0
        
        // Goal completion rate
        let daysMetGoal = filteredDailyTotals.values.filter { $0 >= goalSeconds }.count
        let completionRate = totalDaysInWindow > 0 ? (Double(daysMetGoal) / Double(totalDaysInWindow)) : 0.0
        
        // Books finished
        let finishedBooksCount = books.filter { $0.status == ReadingStatus.finished.rawValue }.count
        
        // Today, This Week, This Month calculations from allTimeDailyTotals
        let todayNormalized = calendar.startOfDay(for: now)
        let readingToday = allTimeDailyTotals[todayNormalized] ?? 0
        
        var readingThisWeek = 0
        var readingThisMonth = 0
        for (date, seconds) in allTimeDailyTotals {
            if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                readingThisWeek += seconds
            }
            if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                readingThisMonth += seconds
            }
        }
        
        let summary = InsightsAnalyticsSummary(
            totalReadingSeconds: totalActiveSeconds,
            averageDailySeconds: avgDailySeconds,
            averageSessionSeconds: avgSessionSeconds,
            totalSessionsCount: sessionCount,
            totalBooksFinishedCount: finishedBooksCount,
            currentStreak: streakInfo.currentStreak,
            longestStreak: streakInfo.longestStreak,
            goalCompletionRate: completionRate,
            totalPagesRead: totalPages,
            readingSecondsToday: readingToday,
            readingSecondsThisWeek: readingThisWeek,
            readingSecondsThisMonth: readingThisMonth
        )
        
        // 3. Daily bar chart data (fixed for the last 7 days)
        let dailyPoints = generateDailyPoints(
            dailyTotals: allTimeDailyTotals,
            dailyGoalSeconds: goalSeconds,
            numberOfDays: 7,
            now: now,
            calendar: calendar
        )
        
        // 4. Weekly trend
        let weeklyTrend = generateWeeklyTrend(
            dailyTotals: allTimeDailyTotals,
            now: now,
            calendar: calendar
        )
        
        // 5. Monthly activity
        let monthlyActivity = generateMonthlyActivity(
            dailyTotals: allTimeDailyTotals,
            now: now,
            calendar: calendar
        )
        
        // 6. Book distribution
        let bookDistribution = generateBookDistribution(
            sessions: filteredSessions,
            books: books
        )
        
        // 7. Calendar heatmap (current month)
        let heatmapPoints = generateHeatmapPoints(
            dailyTotals: allTimeDailyTotals,
            dailyGoalSeconds: goalSeconds,
            now: now,
            calendar: calendar
        )
        
        return (summary, dailyPoints, weeklyTrend, monthlyActivity, bookDistribution, heatmapPoints)
    }
    
    // MARK: - Chart Helper Generators
    
    /// Generates daily reading activity points fixed for the last 7 days.
    private static func generateDailyPoints(
        dailyTotals: [Date: Int],
        dailyGoalSeconds: Int,
        numberOfDays: Int = 7,
        now: Date,
        calendar: Calendar
    ) -> [DailyReadingPoint] {
        let normalizedToday = calendar.startOfDay(for: now)
        var points: [DailyReadingPoint] = []
        
        for offset in (0..<numberOfDays).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: normalizedToday) else { continue }
            let seconds = dailyTotals[date] ?? 0
            let minutes = Double(seconds) / 60.0
            let met = seconds >= dailyGoalSeconds
            let isToday = (date == normalizedToday)
            points.append(DailyReadingPoint(date: date, minutes: minutes, metGoal: met, isToday: isToday))
        }
        
        return points
    }
    
    private static func generateWeeklyTrend(
        dailyTotals: [Date: Int],
        now: Date,
        calendar: Calendar
    ) -> [WeeklyReadingPoint] {
        var points: [WeeklyReadingPoint] = []
        let today = calendar.startOfDay(for: now)
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        
        // Last 8 weeks
        for weekOffset in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .day, value: -(weekOffset * 7 + 6), to: today),
                  let weekEnd = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: today) else { continue }
            
            var totalWeekSeconds = 0
            var current = weekStart
            while current <= weekEnd {
                totalWeekSeconds += (dailyTotals[current] ?? 0)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            
            let label = df.string(from: weekStart)
            points.append(WeeklyReadingPoint(weekStart: weekStart, label: label, minutes: Double(totalWeekSeconds) / 60.0))
        }
        return points
    }
    
    private static func generateMonthlyActivity(
        dailyTotals: [Date: Int],
        now: Date,
        calendar: Calendar
    ) -> [MonthlyReadingPoint] {
        var points: [MonthlyReadingPoint] = []
        let df = DateFormatter()
        df.dateFormat = "MMM"
        
        for monthOffset in (0..<6).reversed() {
            guard let targetDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let comp = calendar.dateComponents([.year, .month], from: targetDate)
            guard let monthStart = calendar.date(from: comp),
                  let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else { continue }
            
            var monthSeconds = 0
            for d in monthRange {
                if let dayDate = calendar.date(byAdding: .day, value: d - 1, to: monthStart) {
                    monthSeconds += (dailyTotals[dayDate] ?? 0)
                }
            }
            let label = df.string(from: monthStart)
            points.append(MonthlyReadingPoint(monthDate: monthStart, label: label, hours: Double(monthSeconds) / 3600.0))
        }
        return points
    }
    
    private static func generateBookDistribution(
        sessions: [ReadingSessionDTO],
        books: [BookDTO]
    ) -> [BookTimePoint] {
        var bookTimeMap: [UUID: Int] = [:]
        for s in sessions {
            guard let bId = s.bookId else { continue }
            bookTimeMap[bId, default: 0] += s.activeSeconds
        }
        
        let totalTimeAll = max(1, bookTimeMap.values.reduce(0, +))
        let booksById = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        
        let sorted = bookTimeMap.sorted { $0.value > $1.value }
        
        return sorted.prefix(6).map { bId, seconds in
            let book = booksById[bId]
            let title = book?.title ?? "Untitled"
            let author = book?.author ?? "Unknown"
            let color = book?.coverColorHex ?? "forest"
            let minutes = Double(seconds) / 60.0
            let percentage = Double(seconds) / Double(totalTimeAll)
            return BookTimePoint(
                bookId: bId,
                title: title,
                author: author,
                coverColorHex: color,
                minutes: minutes,
                percentage: percentage
            )
        }
    }
    
    private static func generateHeatmapPoints(
        dailyTotals: [Date: Int],
        dailyGoalSeconds: Int,
        now: Date,
        calendar: Calendar
    ) -> [HeatmapDayPoint] {
        let comp = calendar.dateComponents([.year, .month], from: now)
        guard let monthStart = calendar.date(from: comp),
              let daysRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }
        
        var points: [HeatmapDayPoint] = []
        for dayNum in daysRange {
            guard let dayDate = calendar.date(byAdding: .day, value: dayNum - 1, to: monthStart) else { continue }
            let seconds = dailyTotals[dayDate] ?? 0
            let minutes = seconds / 60
            
            let intensity: Int
            if seconds == 0 {
                intensity = 0
            } else if seconds >= dailyGoalSeconds {
                intensity = 4 // Full goal met
            } else if seconds >= (dailyGoalSeconds * 2 / 3) {
                intensity = 3 // Good progress
            } else if seconds >= (dailyGoalSeconds / 3) {
                intensity = 2 // Medium
            } else {
                intensity = 1 // Light
            }
            
            points.append(HeatmapDayPoint(date: dayDate, minutes: minutes, intensity: intensity, isCurrentMonth: true))
        }
        return points
    }
    
    /// Computes full-year GitHub-style heatmap points for any given year with session counts,
    /// goal met status, and day-of-year integrity.
    public static func computeYearlyHeatmap(
        sessions: [ReadingSessionDTO],
        year: Int,
        dailyGoalMinutes: Int = 30,
        now: Date = Date(),
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> [HeatmapDayPoint] {
        let goalSeconds = max(60, dailyGoalMinutes * 60)
        
        var dailyTotals: [Date: Int] = [:]
        var dailySessionCounts: [Date: Int] = [:]
        
        let completed = sessions.filter { $0.status == SessionStatus.completed.rawValue }
        for s in completed {
            let activeSec = s.activeSeconds
            guard activeSec > 0 else { continue }
            let end = s.endedAt ?? s.startedAt.addingTimeInterval(Double(activeSec))
            let allocations = DateUtilities.splitSessionAcrossDays(
                startedAt: s.startedAt,
                endedAt: end,
                activeSeconds: activeSec,
                calendar: calendar
            )
            for a in allocations {
                dailyTotals[a.date, default: 0] += a.activeSeconds
            }
            let startDay = calendar.startOfDay(for: s.startedAt)
            dailySessionCounts[startDay, default: 0] += 1
        }
        
        var dateComps = DateComponents()
        dateComps.year = year
        dateComps.month = 1
        dateComps.day = 1
        guard let yearStart = calendar.date(from: dateComps),
              let daysInYear = calendar.range(of: .day, in: .year, for: yearStart) else {
            return []
        }
        
        let normalizedToday = calendar.startOfDay(for: now)
        let currentMonthComps = calendar.dateComponents([.year, .month], from: now)
        
        var points: [HeatmapDayPoint] = []
        for dayOffset in 0..<daysInYear.count {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: yearStart) else { continue }
            let seconds = dailyTotals[dayDate] ?? 0
            let minutes = seconds / 60
            let sCount = dailySessionCounts[dayDate] ?? 0
            let met = seconds >= goalSeconds
            let isToday = (dayDate == normalizedToday)
            
            let dayMonthComps = calendar.dateComponents([.year, .month], from: dayDate)
            let isCurrentMonth = (dayMonthComps == currentMonthComps)
            
            let intensity: Int
            if seconds == 0 {
                intensity = 0
            } else if seconds >= goalSeconds {
                intensity = 4
            } else if seconds >= (goalSeconds * 2 / 3) {
                intensity = 3
            } else if seconds >= (goalSeconds / 3) {
                intensity = 2
            } else {
                intensity = 1
            }
            
            points.append(
                HeatmapDayPoint(
                    date: dayDate,
                    minutes: minutes,
                    intensity: intensity,
                    isCurrentMonth: isCurrentMonth,
                    sessionCount: sCount,
                    metGoal: met,
                    isToday: isToday
                )
            )
        }
        
        return points
    }
}

