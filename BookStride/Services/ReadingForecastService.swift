//
//  ReadingForecastService.swift
//  BookStride
//
//  Mathematical forecasting engine for estimated reading time, reading pace,
//  and projected completion dates derived from actual reading history.
//

import Foundation

public enum ForecastStatus: String, Codable, Equatable {
    case accurate = "Accurate"
    case completed = "Completed"
    case notStarted = "Not Started"
    case insufficientSessionData = "Insufficient Data"
    case missingTotalPages = "Missing Total Pages"
    case invalidProgress = "Invalid Progress"
}

public struct ReadingForecast: Equatable {
    public let status: ForecastStatus
    public let pagesPerHour: Double?
    public let remainingPages: Int?
    public let estimatedRemainingMinutes: Int?
    public let estimatedCompletionDate: Date?
    public let daysToFinish: Int?
    public let explanation: String
    
    public init(
        status: ForecastStatus,
        pagesPerHour: Double? = nil,
        remainingPages: Int? = nil,
        estimatedRemainingMinutes: Int? = nil,
        estimatedCompletionDate: Date? = nil,
        daysToFinish: Int? = nil,
        explanation: String
    ) {
        self.status = status
        self.pagesPerHour = pagesPerHour
        self.remainingPages = remainingPages
        self.estimatedRemainingMinutes = estimatedRemainingMinutes
        self.estimatedCompletionDate = estimatedCompletionDate
        self.daysToFinish = daysToFinish
        self.explanation = explanation
    }
}

public enum ReadingForecastService {
    
    /// Minimum threshold requirements to calculate verified reading speed:
    /// Requires at least 5 pages read and at least 600 seconds (10 mins) of active reading.
    public static let minPagesThreshold = 5
    public static let minDurationSecondsThreshold = 600
    
    /// Computes the verified reading pace (pages per hour) strictly from completed reading sessions.
    /// Prefers recent activity (last 60 days) if sufficient data exists, falling back to all-time sessions.
    /// Returns nil when data is insufficient or invalid, preventing fabricated rates.
    public static func calculateReadingSpeed(
        sessions: [ReadingSessionDTO],
        now: Date = Date(),
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> Double? {
        let completed = sessions.filter { $0.status.caseInsensitiveCompare(SessionStatus.completed.rawValue) == .orderedSame }
        guard !completed.isEmpty else { return nil }
        
        // 1. Attempt calculation using recent sessions (last 60 days)
        if let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: now) {
            let recentSessions = completed.filter { $0.startedAt >= sixtyDaysAgo }
            if let speed = speedFromSessions(recentSessions) {
                return speed
            }
        }
        
        // 2. Fall back to all completed sessions
        return speedFromSessions(completed)
    }
    
    private static func speedFromSessions(_ sessions: [ReadingSessionDTO]) -> Double? {
        var validPages = 0
        var validSeconds = 0
        
        for s in sessions {
            guard let start = s.startPage, let end = s.endPage,
                  end > start, start >= 0,
                  s.activeSeconds >= 60 else { continue }
            
            validPages += (end - start)
            validSeconds += s.activeSeconds
        }
        
        guard validPages >= minPagesThreshold, validSeconds >= minDurationSecondsThreshold else {
            return nil
        }
        
        let activeHours = Double(validSeconds) / 3600.0
        guard activeHours > 0 else { return nil }
        let rate = Double(validPages) / activeHours
        return rate.isFinite && rate > 0 ? rate : nil
    }
    
    /// Computes a comprehensive completion forecast for a book.
    ///
    /// Formula:
    /// 1. `remainingPages = totalPages - currentPage`
    /// 2. `remainingHours = remainingPages / pagesPerHour`
    /// 3. `dailyHours = max(5, dailyReadingMinutes) / 60.0`
    /// 4. `daysNeeded = ceil(remainingHours / dailyHours)`
    /// 5. `completionDate = now + daysNeeded`
    public static func forecastBookCompletion(
        currentPage: Int?,
        totalPages: Int?,
        isFinished: Bool,
        sessions: [ReadingSessionDTO],
        dailyReadingMinutes: Int = 30,
        now: Date = Date(),
        calendar: Calendar = DateUtilities.defaultCalendar
    ) -> ReadingForecast {
        // Case 1: Book is already finished
        if isFinished {
            return ReadingForecast(
                status: .completed,
                explanation: "You have finished reading this book."
            )
        }
        
        // Case 2: Missing total page count
        guard let total = totalPages, total > 0 else {
            return ReadingForecast(
                status: .missingTotalPages,
                explanation: "Total page count is not specified for this book."
            )
        }
        
        let current = currentPage ?? 0
        
        // Case 3: Invalid progress bounds
        if current > total || current < 0 {
            return ReadingForecast(
                status: .invalidProgress,
                explanation: "Current page (\(current)) exceeds total book pages (\(total))."
            )
        }
        
        // Case 4: Current page equals total (completed)
        if current >= total {
            return ReadingForecast(
                status: .completed,
                remainingPages: 0,
                explanation: "You have reached the final page of this book."
            )
        }
        
        let remaining = total - current
        
        // Case 5: Evaluate reading speed from session logs
        guard let speed = calculateReadingSpeed(sessions: sessions, now: now, calendar: calendar), speed > 0 else {
            return ReadingForecast(
                status: .insufficientSessionData,
                remainingPages: remaining,
                explanation: "Log at least 5 pages over 10 minutes to calculate a reading pace forecast."
            )
        }
        
        // Safe calculation: division by zero prevented by guards above
        let remainingHours = Double(remaining) / speed
        let remainingMinutes = max(1, Int(ceil(remainingHours * 60.0)))
        
        let effectiveDailyMinutes = max(5, dailyReadingMinutes)
        let dailyHours = Double(effectiveDailyMinutes) / 60.0
        let daysNeeded = max(1, Int(ceil(remainingHours / dailyHours)))
        
        let estimatedDate = calendar.date(byAdding: .day, value: daysNeeded, to: now)
        
        let formattedSpeed = String(format: "%.1f", speed)
        let explanation = "Approx. \(daysNeeded) days remaining at \(formattedSpeed) pages/hr (assuming \(effectiveDailyMinutes)m/day)."
        
        return ReadingForecast(
            status: .accurate,
            pagesPerHour: speed,
            remainingPages: remaining,
            estimatedRemainingMinutes: remainingMinutes,
            estimatedCompletionDate: estimatedDate,
            daysToFinish: daysNeeded,
            explanation: explanation
        )
    }
}
