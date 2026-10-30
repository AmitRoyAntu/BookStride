//
//  WidgetSharedModels.swift
//  BookStride
//
//  Shared models, snapshots, and configuration between the BookStride main app
//  and its WidgetKit extension.
//

import Foundation

public enum WidgetSessionState: String, Codable {
    case idle = "Idle"
    case active = "Active"
    case paused = "Paused"
    case finished = "Finished"
    
    public var label: String {
        switch self {
        case .idle: return "Ready"
        case .active: return "Reading"
        case .paused: return "Paused"
        case .finished: return "Finished"
        }
    }
}

public struct TodayProgressSnapshot: Codable, Equatable {
    public var date: Date
    public var todaySeconds: Int
    public var dailyGoalSeconds: Int
    public var sessionCountToday: Int
    public var currentStreakDays: Int
    public var lastUpdated: Date
    
    public init(
        date: Date = Date(),
        todaySeconds: Int = 0,
        dailyGoalSeconds: Int = 1800,
        sessionCountToday: Int = 0,
        currentStreakDays: Int = 0,
        lastUpdated: Date = Date()
    ) {
        self.date = date
        self.todaySeconds = todaySeconds
        self.dailyGoalSeconds = dailyGoalSeconds
        self.sessionCountToday = sessionCountToday
        self.currentStreakDays = currentStreakDays
        self.lastUpdated = lastUpdated
    }
    
    public var progressFraction: Double {
        guard dailyGoalSeconds > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(todaySeconds) / Double(dailyGoalSeconds)))
    }
}

public struct WidgetReadingSnapshot: Codable, Equatable {
    public var state: WidgetSessionState
    public var sessionId: UUID?
    public var bookId: UUID?
    public var bookTitle: String
    public var bookAuthor: String
    public var startedAt: Date?
    public var lastResumedAt: Date?
    public var lastPausedAt: Date?
    public var accumulatedActiveSeconds: Int
    public var todaySeconds: Int
    public var dailyGoalSeconds: Int
    public var isPaused: Bool
    public var lastUpdated: Date
    
    public init(
        state: WidgetSessionState = .idle,
        sessionId: UUID? = nil,
        bookId: UUID? = nil,
        bookTitle: String = "Ready to Read",
        bookAuthor: String = "",
        startedAt: Date? = nil,
        lastResumedAt: Date? = nil,
        lastPausedAt: Date? = nil,
        accumulatedActiveSeconds: Int = 0,
        todaySeconds: Int = 0,
        dailyGoalSeconds: Int = 1800,
        isPaused: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.state = state
        self.sessionId = sessionId
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.startedAt = startedAt
        self.lastResumedAt = lastResumedAt
        self.lastPausedAt = lastPausedAt
        self.accumulatedActiveSeconds = accumulatedActiveSeconds
        self.todaySeconds = todaySeconds
        self.dailyGoalSeconds = dailyGoalSeconds
        self.isPaused = isPaused
        self.lastUpdated = lastUpdated
    }
    
    /// The virtual start date used by WidgetKit Text(date, style: .timer).
    /// When actively running, virtualStart = (lastResumedAt ?? startedAt) - accumulatedActiveSeconds.
    /// This allows WidgetKit to display a live second-by-second countdown/up without background process wakes.
    public var virtualTimerStartDate: Date? {
        guard state == .active, !isPaused else { return nil }
        let anchor = lastResumedAt ?? startedAt ?? Date()
        return anchor.addingTimeInterval(-Double(accumulatedActiveSeconds))
    }
    
    /// Static elapsed duration for paused, idle, or completed states.
    public var frozenElapsedSeconds: Int {
        accumulatedActiveSeconds
    }
    
    public var todayProgressFraction: Double {
        guard dailyGoalSeconds > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(todaySeconds) / Double(dailyGoalSeconds)))
    }
}

public enum AppGroupConfig {
    public static let appGroupId = "group.com.amitroy.BookStride"
    public static let activeStateKey = "BookStride_ActiveSessionState_v1"
    public static let todayProgressKey = "BookStride_TodayProgress_v1"
    public static let widgetSnapshotKey = "BookStride_WidgetSnapshot_v1"
    public static let widgetURLString = "bookstride://timer"
    public static let widgetStartURLString = "bookstride://start"
    
    /// Accesses the shared app group UserDefaults container, falling back to standard user defaults.
    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupId) ?? .standard
    }
}

