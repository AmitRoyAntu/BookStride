//
//  ReadingActivityAttributes.swift
//  BookStride
//
//  ActivityKit attributes and dynamic content state for BookStride reading sessions.
//  Used by both the main app and the BookStride Widget Extension.
//

import Foundation
#if canImport(ActivityKit) && os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit

@available(iOS 16.1, *)
public struct ReadingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var bookTitle: String
        public var author: String
        public var isPaused: Bool
        public var accumulatedSeconds: Int
        public var resumeStartDate: Date?
        public var todaySeconds: Int
        public var dailyGoalSeconds: Int
        public var coverColorHex: String
        
        public init(
            bookTitle: String,
            author: String = "",
            isPaused: Bool = false,
            accumulatedSeconds: Int = 0,
            resumeStartDate: Date? = nil,
            todaySeconds: Int = 0,
            dailyGoalSeconds: Int = 1800,
            coverColorHex: String = "forest"
        ) {
            self.bookTitle = bookTitle
            self.author = author
            self.isPaused = isPaused
            self.accumulatedSeconds = accumulatedSeconds
            self.resumeStartDate = resumeStartDate
            self.todaySeconds = todaySeconds
            self.dailyGoalSeconds = dailyGoalSeconds
            self.coverColorHex = coverColorHex
        }
    }
    
    public var sessionId: String
    public var bookId: String?
    
    public init(sessionId: String, bookId: String? = nil) {
        self.sessionId = sessionId
        self.bookId = bookId
    }
}
#else
public struct ReadingActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var bookTitle: String
        public var author: String
        public var isPaused: Bool
        public var accumulatedSeconds: Int
        public var resumeStartDate: Date?
        public var todaySeconds: Int
        public var dailyGoalSeconds: Int
        public var coverColorHex: String
        
        public init(
            bookTitle: String,
            author: String = "",
            isPaused: Bool = false,
            accumulatedSeconds: Int = 0,
            resumeStartDate: Date? = nil,
            todaySeconds: Int = 0,
            dailyGoalSeconds: Int = 1800,
            coverColorHex: String = "forest"
        ) {
            self.bookTitle = bookTitle
            self.author = author
            self.isPaused = isPaused
            self.accumulatedSeconds = accumulatedSeconds
            self.resumeStartDate = resumeStartDate
            self.todaySeconds = todaySeconds
            self.dailyGoalSeconds = dailyGoalSeconds
            self.coverColorHex = coverColorHex
        }
    }
    
    public var sessionId: String
    public var bookId: String?
    
    public init(sessionId: String, bookId: String? = nil) {
        self.sessionId = sessionId
        self.bookId = bookId
    }
}
#endif
