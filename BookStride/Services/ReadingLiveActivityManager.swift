//
//  ReadingLiveActivityManager.swift
//  BookStride
//
//  Coordinates ActivityKit lifecycle for Reading Live Activities.
//  Handles start, pause, resume, finish, reconciliation on launch,
//  duplicate prevention, and the 8-hour activity cap.
//

import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

public final class ReadingLiveActivityManager {
    public static let shared = ReadingLiveActivityManager()
    
    #if canImport(ActivityKit) && os(iOS)
    @available(iOS 16.1, *)
    private var currentActivity: Activity<ReadingActivityAttributes>? {
        get {
            Activity<ReadingActivityAttributes>.activities.first
        }
    }
    #endif
    
    private init() {}
    
    // MARK: - Authorization Check
    
    public var isLiveActivitiesEnabled: Bool {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }
    
    // MARK: - Lifecycle Management
    
    /// Starts a Live Activity for a reading session if permitted and not already active.
    public func startActivity(
        sessionId: UUID,
        bookId: UUID?,
        bookTitle: String,
        author: String = "",
        coverColorHex: String = "forest",
        accumulatedSeconds: Int = 0,
        isPaused: Bool = false,
        lastResumedAt: Date? = Date(),
        todaySeconds: Int = 0,
        dailyGoalSeconds: Int = 1800
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *), isLiveActivitiesEnabled else { return }
        
        // End any duplicate or stale activities first
        endExistingActivities()
        
        let attributes = ReadingActivityAttributes(
            sessionId: sessionId.uuidString,
            bookId: bookId?.uuidString
        )
        
        let state = ReadingActivityAttributes.ContentState(
            bookTitle: bookTitle,
            author: author,
            isPaused: isPaused,
            accumulatedSeconds: accumulatedSeconds,
            resumeStartDate: isPaused ? nil : lastResumedAt,
            todaySeconds: todaySeconds,
            dailyGoalSeconds: dailyGoalSeconds,
            coverColorHex: coverColorHex
        )
        
        // 8-hour ActivityKit limit cap
        let eightHoursFromNow = Date().addingTimeInterval(8 * 3600)
        let activityContent = ActivityContent(
            state: state,
            staleDate: eightHoursFromNow,
            relevanceScore: 100.0
        )
        
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
        } catch {
            // Live Activities request failed (e.g. system permission or simulator restriction)
        }
        #endif
    }
    
    /// Updates an existing Live Activity when paused, resumed, or progress advances.
    public func updateActivity(
        bookTitle: String,
        author: String = "",
        isPaused: Bool,
        accumulatedSeconds: Int,
        lastResumedAt: Date?,
        todaySeconds: Int,
        dailyGoalSeconds: Int,
        coverColorHex: String = "forest"
    ) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *) else { return }
        
        let state = ReadingActivityAttributes.ContentState(
            bookTitle: bookTitle,
            author: author,
            isPaused: isPaused,
            accumulatedSeconds: accumulatedSeconds,
            resumeStartDate: isPaused ? nil : lastResumedAt,
            todaySeconds: todaySeconds,
            dailyGoalSeconds: dailyGoalSeconds,
            coverColorHex: coverColorHex
        )
        
        let eightHoursFromNow = Date().addingTimeInterval(8 * 3600)
        let activityContent = ActivityContent(
            state: state,
            staleDate: eightHoursFromNow
        )
        
        Task {
            for activity in Activity<ReadingActivityAttributes>.activities {
                await activity.update(activityContent)
            }
        }
        #endif
    }
    
    /// Ends all active reading Live Activities when the session completes or is cancelled.
    public func endActivity(dismissImmediately: Bool = false) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *) else { return }
        
        let dismissalPolicy: ActivityUIDismissalPolicy = dismissImmediately ? .immediate : .after(Date().addingTimeInterval(4))
        
        Task {
            for activity in Activity<ReadingActivityAttributes>.activities {
                var finalState = activity.content.state
                finalState.isPaused = true
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: dismissalPolicy)
            }
        }
        #endif
    }
    
    /// Reconciles Live Activities upon app launch or foreground transition.
    /// Cancels orphan activities if no reading session is currently active in app storage.
    public func reconcile(with activeSessionState: ActiveSessionState?) {
        #if canImport(ActivityKit) && os(iOS)
        guard #available(iOS 16.1, *) else { return }
        
        let runningActivities = Activity<ReadingActivityAttributes>.activities
        guard !runningActivities.isEmpty else { return }
        
        if let session = activeSessionState {
            // Keep matching activity, dismiss any duplicate mismatches
            for activity in runningActivities {
                if activity.attributes.sessionId != session.sessionId.uuidString {
                    Task {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                }
            }
        } else {
            // No session active in app -> clean up all orphan activities
            Task {
                for activity in runningActivities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        #endif
    }
    
    private func endExistingActivities() {
        #if canImport(ActivityKit) && os(iOS)
        if #available(iOS 16.1, *) {
            for activity in Activity<ReadingActivityAttributes>.activities {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        #endif
    }
}
