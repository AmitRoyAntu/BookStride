//
//  ReadingSession.swift
//  BookStride
//
//  SwiftData persistent model representing a single reading session.
//

import Foundation
import SwiftData

@Model
public final class ReadingSession {
    public var id: UUID = UUID()
    public var startedAt: Date = Date()
    public var endedAt: Date?
    public var statusRawValue: String = SessionStatus.completed.rawValue
    
    // Active time tracking with pause intervals
    public var accumulatedActiveSeconds: Int = 0
    public var lastResumedAt: Date?
    public var lastPausedAt: Date?
    public var pausedDurationSeconds: Int = 0
    
    // Page tracking
    public var startPage: Int?
    public var endPage: Int?
    
    // Notes & Reflection
    public var notes: String?
    
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    
    public var book: Book?
    
    public init(
        id: UUID = UUID(),
        book: Book? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: SessionStatus = .completed,
        accumulatedActiveSeconds: Int = 0,
        lastResumedAt: Date? = nil,
        lastPausedAt: Date? = nil,
        pausedDurationSeconds: Int = 0,
        startPage: Int? = nil,
        endPage: Int? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.book = book
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.statusRawValue = status.rawValue
        self.accumulatedActiveSeconds = accumulatedActiveSeconds
        self.lastResumedAt = lastResumedAt
        self.lastPausedAt = lastPausedAt
        self.pausedDurationSeconds = pausedDurationSeconds
        self.startPage = startPage
        self.endPage = endPage
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var status: SessionStatus {
        get { SessionStatus(rawValue: statusRawValue) ?? .completed }
        set { statusRawValue = newValue.rawValue }
    }
    
    /// Current calculated active reading duration in seconds.
    /// Excludes all paused durations.
    public var activeDurationSeconds: Int {
        switch status {
        case .completed:
            if accumulatedActiveSeconds > 0 {
                return accumulatedActiveSeconds
            } else if let end = endedAt {
                let rawSpan = Int(max(0, end.timeIntervalSince(startedAt)))
                return max(0, rawSpan - pausedDurationSeconds)
            }
            return 0
            
        case .active:
            let runningTime: Int
            if let resume = lastResumedAt {
                runningTime = max(0, Int(Date().timeIntervalSince(resume)))
            } else {
                runningTime = max(0, Int(Date().timeIntervalSince(startedAt)))
            }
            return accumulatedActiveSeconds + runningTime
            
        case .paused:
            return accumulatedActiveSeconds
            
        case .cancelled:
            return 0
        }
    }
    
    public var pagesRead: Int? {
        guard let start = startPage, let end = endPage, end >= start else { return nil }
        return end - start
    }
}
