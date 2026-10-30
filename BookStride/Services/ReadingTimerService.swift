//
//  ReadingTimerService.swift
//  BookStride
//
//  Robust timer and session state management with state restoration and stale session protection.
//

import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct ActiveSessionState: Codable, Equatable {
    public var sessionId: UUID
    public var bookId: UUID?
    public var bookTitle: String
    public var startedAt: Date
    public var lastResumedAt: Date?
    public var lastPausedAt: Date?
    public var accumulatedActiveSeconds: Int
    public var pausedDurationSeconds: Int
    public var isPaused: Bool
    public var startPage: Int?
    
    public init(
        sessionId: UUID = UUID(),
        bookId: UUID? = nil,
        bookTitle: String = "Untitled",
        startedAt: Date = Date(),
        lastResumedAt: Date? = nil,
        lastPausedAt: Date? = nil,
        accumulatedActiveSeconds: Int = 0,
        pausedDurationSeconds: Int = 0,
        isPaused: Bool = false,
        startPage: Int? = nil
    ) {
        self.sessionId = sessionId
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.startedAt = startedAt
        self.lastResumedAt = lastResumedAt
        self.lastPausedAt = lastPausedAt
        self.accumulatedActiveSeconds = accumulatedActiveSeconds
        self.pausedDurationSeconds = pausedDurationSeconds
        self.isPaused = isPaused
        self.startPage = startPage
    }
}

public final class ReadingTimerService: ObservableObject {
    public static let shared = ReadingTimerService()
    
    // Stale session threshold (4 hours)
    public static let staleThresholdSeconds: TimeInterval = 4 * 3600
    private static let storageKey = "BookStride_ActiveSessionState_v1"
    
    @Published public private(set) var activeState: ActiveSessionState?
    @Published public private(set) var currentElapsedSeconds: Int = 0
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public var showStaleSessionAlert: Bool = false
    @Published public var unmonitoredElapsedSeconds: Int = 0
    
    // Deep-link triggers to navigate seamlessly to the timer or book picker
    @Published public var shouldOpenTimerModal: Bool = false
    @Published public var shouldTriggerBookPicker: Bool = false
    
    // Last action timestamp for debouncing widget taps and preventing duplicates
    private var lastWidgetActionTimestamp: Date = .distantPast
    
    private var ticker: AnyCancellable?
    private let userDefaults: UserDefaults
    
    public init(userDefaults: UserDefaults = AppGroupConfig.sharedDefaults) {
        self.userDefaults = userDefaults
        restoreActiveSession()
    }
    
    // MARK: - Lifecycle & State Restoration
    
    public func restoreActiveSession(now: Date = Date()) {
        var data = userDefaults.data(forKey: Self.storageKey) ?? userDefaults.data(forKey: "ReadFlow_ActiveSessionState_v1")
        if data == nil && userDefaults == AppGroupConfig.sharedDefaults {
            data = UserDefaults.standard.data(forKey: Self.storageKey) ?? UserDefaults.standard.data(forKey: "ReadFlow_ActiveSessionState_v1")
        }
        guard let validData = data,
              let state = try? JSONDecoder().decode(ActiveSessionState.self, from: validData) else {
            return
        }
        
        self.activeState = state
        self.isPaused = state.isPaused
        self.isRunning = !state.isPaused
        
        // Check for stale session if app was terminated/backgrounded while timer was running
        if !state.isPaused, let resume = state.lastResumedAt ?? Optional(state.startedAt) {
            let elapsedSinceResume = now.timeIntervalSince(resume)
            let totalRunningSeconds = state.accumulatedActiveSeconds + Int(max(0, elapsedSinceResume))
            
            if elapsedSinceResume > Self.staleThresholdSeconds {
                self.unmonitoredElapsedSeconds = totalRunningSeconds
                self.showStaleSessionAlert = true
                // Pause timer while user reviews stale session
                pauseSession(now: now)
                return
            }
        }
        
        recalculateElapsed(now: now)
        if isRunning {
            startTicker()
        }
        #if !WIDGET_EXTENSION
        ReadingLiveActivityManager.shared.reconcile(with: self.activeState)
        #endif
    }
    
    private func persistActiveState() {
        if let state = activeState {
            if let data = try? JSONEncoder().encode(state) {
                userDefaults.set(data, forKey: Self.storageKey)
                if userDefaults == AppGroupConfig.sharedDefaults && userDefaults != .standard {
                    UserDefaults.standard.set(data, forKey: Self.storageKey)
                }
            }
        } else {
            userDefaults.removeObject(forKey: Self.storageKey)
            if userDefaults == AppGroupConfig.sharedDefaults && userDefaults != .standard {
                UserDefaults.standard.removeObject(forKey: Self.storageKey)
            }
        }
        updateWidgetSnapshot()
    }
    
    /// Updates today's cached progress in shared storage so the widget Medium layout stays fresh.
    public func updateTodayProgress(
        todaySeconds: Int,
        dailyGoalSeconds: Int,
        sessionCountToday: Int,
        currentStreakDays: Int
    ) {
        let snapshot = TodayProgressSnapshot(
            date: Date(),
            todaySeconds: todaySeconds,
            dailyGoalSeconds: dailyGoalSeconds,
            sessionCountToday: sessionCountToday,
            currentStreakDays: currentStreakDays,
            lastUpdated: Date()
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            userDefaults.set(data, forKey: AppGroupConfig.todayProgressKey)
            if userDefaults == AppGroupConfig.sharedDefaults && userDefaults != .standard {
                UserDefaults.standard.set(data, forKey: AppGroupConfig.todayProgressKey)
            }
        }
        updateWidgetSnapshot()
    }
    
    /// Updates widget snapshot and notifies WidgetCenter.
    public func updateWidgetSnapshot() {
        var todayData = userDefaults.data(forKey: AppGroupConfig.todayProgressKey)
        if todayData == nil && userDefaults == AppGroupConfig.sharedDefaults {
            todayData = UserDefaults.standard.data(forKey: AppGroupConfig.todayProgressKey)
        }
        let todayProgress = (todayData != nil) ? (try? JSONDecoder().decode(TodayProgressSnapshot.self, from: todayData!)) : nil
        
        let widgetState: WidgetSessionState
        if let state = activeState {
            widgetState = state.isPaused ? .paused : .active
        } else {
            widgetState = .idle
        }
        
        let widgetSnapshot = WidgetReadingSnapshot(
            state: widgetState,
            sessionId: activeState?.sessionId,
            bookId: activeState?.bookId,
            bookTitle: activeState?.bookTitle ?? "Ready to Read",
            bookAuthor: "",
            startedAt: activeState?.startedAt,
            lastResumedAt: activeState?.lastResumedAt,
            lastPausedAt: activeState?.lastPausedAt,
            accumulatedActiveSeconds: activeState?.accumulatedActiveSeconds ?? 0,
            todaySeconds: todayProgress?.todaySeconds ?? 0,
            dailyGoalSeconds: todayProgress?.dailyGoalSeconds ?? 1800,
            isPaused: activeState?.isPaused ?? false,
            lastUpdated: Date()
        )
        
        if let data = try? JSONEncoder().encode(widgetSnapshot) {
            userDefaults.set(data, forKey: AppGroupConfig.widgetSnapshotKey)
            if userDefaults == AppGroupConfig.sharedDefaults && userDefaults != .standard {
                UserDefaults.standard.set(data, forKey: AppGroupConfig.widgetSnapshotKey)
            }
        }
        
        notifyWidgetReload()
    }
    
    public func notifyWidgetReload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
    
    /// Safely toggles pause/resume from the WidgetKit action button with debounce protection.
    public func toggleTimerFromWidget(now: Date = Date()) {
        guard now.timeIntervalSince(lastWidgetActionTimestamp) > 0.3 else { return }
        lastWidgetActionTimestamp = now
        
        restoreActiveSession(now: now)
        guard let state = activeState else { return }
        
        if state.isPaused {
            resumeSession(now: now)
        } else {
            pauseSession(now: now)
        }
    }
    
    /// Safely finishes the active session from WidgetKit or Live Activity intent.
    public func finishSessionFromWidget(now: Date = Date()) {
        restoreActiveSession(now: now)
        _ = finishSession(now: now)
        updateWidgetSnapshot()
    }
    
    // MARK: - Actions
    
    /// Starts a new reading session. Only allows one active session at a time.
    @discardableResult
    public func startSession(
        bookId: UUID?,
        bookTitle: String,
        startPage: Int? = nil,
        now: Date = Date()
    ) -> Bool {
        guard activeState == nil else {
            // Already an active session in progress
            return false
        }
        
        let state = ActiveSessionState(
            sessionId: UUID(),
            bookId: bookId,
            bookTitle: bookTitle,
            startedAt: now,
            lastResumedAt: now,
            lastPausedAt: nil,
            accumulatedActiveSeconds: 0,
            pausedDurationSeconds: 0,
            isPaused: false,
            startPage: startPage
        )
        
        self.activeState = state
        self.isRunning = true
        self.isPaused = false
        self.currentElapsedSeconds = 0
        persistActiveState()
        startTicker()
        
        // Start Live Activity
        #if !WIDGET_EXTENSION
        let todayData = userDefaults.data(forKey: AppGroupConfig.todayProgressKey)
        let todayProgress = (todayData != nil) ? (try? JSONDecoder().decode(TodayProgressSnapshot.self, from: todayData!)) : nil
        ReadingLiveActivityManager.shared.startActivity(
            sessionId: state.sessionId,
            bookId: state.bookId,
            bookTitle: state.bookTitle,
            accumulatedSeconds: 0,
            isPaused: false,
            lastResumedAt: now,
            todaySeconds: todayProgress?.todaySeconds ?? 0,
            dailyGoalSeconds: todayProgress?.dailyGoalSeconds ?? 1800
        )
        #endif
        return true
    }
    
    /// Pauses the active reading session. Paused time is never counted as reading.
    public func pauseSession(now: Date = Date()) {
        guard var state = activeState, !state.isPaused else { return }
        
        // Calculate active time up to pause timestamp
        if let resume = state.lastResumedAt {
            let chunk = max(0, Int(now.timeIntervalSince(resume)))
            state.accumulatedActiveSeconds += chunk
        }
        state.lastResumedAt = nil
        state.lastPausedAt = now
        state.isPaused = true
        
        self.activeState = state
        self.isRunning = false
        self.isPaused = true
        self.currentElapsedSeconds = state.accumulatedActiveSeconds
        
        persistActiveState()
        stopTicker()
        
        #if !WIDGET_EXTENSION
        let todayData = userDefaults.data(forKey: AppGroupConfig.todayProgressKey)
        let todayProgress = (todayData != nil) ? (try? JSONDecoder().decode(TodayProgressSnapshot.self, from: todayData!)) : nil
        ReadingLiveActivityManager.shared.updateActivity(
            bookTitle: state.bookTitle,
            isPaused: true,
            accumulatedSeconds: state.accumulatedActiveSeconds,
            lastResumedAt: nil,
            todaySeconds: todayProgress?.todaySeconds ?? 0,
            dailyGoalSeconds: todayProgress?.dailyGoalSeconds ?? 1800
        )
        #endif
    }
    
    /// Resumes the paused reading session.
    public func resumeSession(now: Date = Date()) {
        guard var state = activeState, state.isPaused else { return }
        
        if let pauseStart = state.lastPausedAt {
            let pauseChunk = max(0, Int(now.timeIntervalSince(pauseStart)))
            state.pausedDurationSeconds += pauseChunk
        }
        state.lastPausedAt = nil
        state.lastResumedAt = now
        state.isPaused = false
        
        self.activeState = state
        self.isRunning = true
        self.isPaused = false
        
        persistActiveState()
        recalculateElapsed(now: now)
        startTicker()
        
        #if !WIDGET_EXTENSION
        let todayData = userDefaults.data(forKey: AppGroupConfig.todayProgressKey)
        let todayProgress = (todayData != nil) ? (try? JSONDecoder().decode(TodayProgressSnapshot.self, from: todayData!)) : nil
        ReadingLiveActivityManager.shared.updateActivity(
            bookTitle: state.bookTitle,
            isPaused: false,
            accumulatedSeconds: state.accumulatedActiveSeconds,
            lastResumedAt: now,
            todaySeconds: todayProgress?.todaySeconds ?? 0,
            dailyGoalSeconds: todayProgress?.dailyGoalSeconds ?? 1800
        )
        #endif
    }
    
    /// Resolves a stale session with user-chosen adjustment.
    public func resolveStaleSession(action: StaleSessionResolution, customMinutes: Int = 30) {
        showStaleSessionAlert = false
        guard var state = activeState else { return }
        
        switch action {
        case .keepCapped(let cappedSeconds):
            state.accumulatedActiveSeconds = min(unmonitoredElapsedSeconds, cappedSeconds)
            state.lastResumedAt = nil
            state.lastPausedAt = Date()
            state.isPaused = true
            self.activeState = state
            self.currentElapsedSeconds = state.accumulatedActiveSeconds
            persistActiveState()
            
        case .customDuration:
            let seconds = max(60, customMinutes * 60)
            state.accumulatedActiveSeconds = seconds
            state.lastResumedAt = nil
            state.lastPausedAt = Date()
            state.isPaused = true
            self.activeState = state
            self.currentElapsedSeconds = state.accumulatedActiveSeconds
            persistActiveState()
            
        case .discard:
            cancelSession()
        }
    }
    
    /// Prepares session completion data. Returns snapshot of session.
    public func finishSession(
        endPage: Int? = nil,
        notes: String? = nil,
        now: Date = Date()
    ) -> CompletedSessionSnapshot? {
        guard var state = activeState else { return nil }
        
        // If still running, fold final segment
        if !state.isPaused, let resume = state.lastResumedAt {
            let finalChunk = max(0, Int(now.timeIntervalSince(resume)))
            state.accumulatedActiveSeconds += finalChunk
        } else if state.isPaused, let pauseStart = state.lastPausedAt {
            let finalPause = max(0, Int(now.timeIntervalSince(pauseStart)))
            state.pausedDurationSeconds += finalPause
        }
        
        let activeSeconds = max(0, state.accumulatedActiveSeconds)
        let snapshot = CompletedSessionSnapshot(
            id: state.sessionId,
            bookId: state.bookId,
            bookTitle: state.bookTitle,
            startedAt: state.startedAt,
            endedAt: now,
            accumulatedActiveSeconds: activeSeconds,
            pausedDurationSeconds: state.pausedDurationSeconds,
            startPage: state.startPage,
            endPage: endPage,
            notes: notes
        )
        
        // Clear active session state
        clearSession()
        return snapshot
    }
    
    /// Cancels and discards active session.
    public func cancelSession() {
        clearSession()
    }
    
    private func clearSession() {
        stopTicker()
        self.activeState = nil
        self.isRunning = false
        self.isPaused = false
        self.currentElapsedSeconds = 0
        persistActiveState()
        #if !WIDGET_EXTENSION
        ReadingLiveActivityManager.shared.endActivity()
        #endif
    }
    
    // MARK: - Elapsed Time Calculation
    
    public func recalculateElapsed(now: Date = Date()) {
        guard let state = activeState else {
            currentElapsedSeconds = 0
            return
        }
        
        if state.isPaused {
            currentElapsedSeconds = state.accumulatedActiveSeconds
        } else {
            let segment: Int
            if let resume = state.lastResumedAt {
                segment = max(0, Int(now.timeIntervalSince(resume)))
            } else {
                segment = max(0, Int(now.timeIntervalSince(state.startedAt)))
            }
            currentElapsedSeconds = state.accumulatedActiveSeconds + segment
        }
    }
    
    private func startTicker() {
        stopTicker()
        ticker = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.recalculateElapsed()
            }
    }
    
    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}

public enum StaleSessionResolution {
    case keepCapped(seconds: Int)
    case customDuration
    case discard
}

public struct CompletedSessionSnapshot: Equatable {
    public let id: UUID
    public let bookId: UUID?
    public let bookTitle: String
    public let startedAt: Date
    public let endedAt: Date
    public let accumulatedActiveSeconds: Int
    public let pausedDurationSeconds: Int
    public let startPage: Int?
    public let endPage: Int?
    public let notes: String?
    
    public init(
        id: UUID,
        bookId: UUID?,
        bookTitle: String,
        startedAt: Date,
        endedAt: Date,
        accumulatedActiveSeconds: Int,
        pausedDurationSeconds: Int,
        startPage: Int?,
        endPage: Int?,
        notes: String?
    ) {
        self.id = id
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.accumulatedActiveSeconds = accumulatedActiveSeconds
        self.pausedDurationSeconds = pausedDurationSeconds
        self.startPage = startPage
        self.endPage = endPage
        self.notes = notes
    }
}

