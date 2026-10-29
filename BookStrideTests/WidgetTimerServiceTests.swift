//
//  WidgetTimerServiceTests.swift
//  BookStrideTests
//
//  Unit tests for WidgetKit snapshot models, virtual timer calculations,
//  and debounce / duplicate-tap protection.
//

import Foundation

public enum WidgetTimerServiceTests {
    public static func runAll() {
        print("▶ Running WidgetTimerServiceTests...")
        testVirtualTimerStartDateCalculation()
        testWidgetSnapshotStateTransitions()
        testWidgetActionDebounceProtection()
        testTodayProgressCalculation()
        print("✅ WidgetTimerServiceTests passed successfully.\n")
    }
    
    private static func testVirtualTimerStartDateCalculation() {
        let now = Date(timeIntervalSince1970: 50000)
        
        // 1. Freshly started active session (0 accumulated seconds)
        let freshSnapshot = WidgetReadingSnapshot(
            state: .active,
            bookTitle: "Atomic Habits",
            startedAt: now,
            lastResumedAt: now,
            accumulatedActiveSeconds: 0,
            isPaused: false
        )
        assert(freshSnapshot.virtualTimerStartDate == now, "Virtual start date should match startedAt when 0 accumulated seconds")
        
        // 2. Resumed active session (accumulated 600s, resumed at now)
        // Virtual start must be now - 600s
        let resumedSnapshot = WidgetReadingSnapshot(
            state: .active,
            bookTitle: "Atomic Habits",
            startedAt: now.addingTimeInterval(-1200),
            lastResumedAt: now,
            accumulatedActiveSeconds: 600,
            isPaused: false
        )
        let expectedVirtual = now.addingTimeInterval(-600)
        assert(resumedSnapshot.virtualTimerStartDate == expectedVirtual, "Virtual start must be offset by accumulatedActiveSeconds")
        
        // 3. Paused session: virtual start must be nil to prevent continuous ticking in widget
        let pausedSnapshot = WidgetReadingSnapshot(
            state: .paused,
            bookTitle: "Atomic Habits",
            startedAt: now.addingTimeInterval(-1200),
            accumulatedActiveSeconds: 600,
            isPaused: true
        )
        assert(pausedSnapshot.virtualTimerStartDate == nil, "Paused snapshot must return nil virtual start date")
        assert(pausedSnapshot.frozenElapsedSeconds == 600, "Frozen elapsed seconds should be 600")
        
        // 4. Idle session: virtual start must be nil
        let idleSnapshot = WidgetReadingSnapshot(state: .idle)
        assert(idleSnapshot.virtualTimerStartDate == nil, "Idle snapshot must return nil virtual start date")
        assert(idleSnapshot.frozenElapsedSeconds == 0, "Idle frozen elapsed should be 0")
    }
    
    private static func testWidgetSnapshotStateTransitions() {
        let defaultsSuite = "test_widget_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let t0 = Date(timeIntervalSince1970: 1000)
        
        // Start session
        let started = service.startSession(bookId: UUID(), bookTitle: "Clean Code", now: t0)
        assert(started, "Session should start")
        
        // Read generated widget snapshot
        guard let data1 = defaults.data(forKey: AppGroupConfig.widgetSnapshotKey),
              let snap1 = try? JSONDecoder().decode(WidgetReadingSnapshot.self, from: data1) else {
            fatalError("Widget snapshot should be persisted on start")
        }
        assert(snap1.state == .active, "Snapshot state should be active")
        assert(snap1.bookTitle == "Clean Code", "Book title should match")
        assert(!snap1.isPaused, "Should not be paused")
        
        // Pause at t0 + 300s
        let t1 = t0.addingTimeInterval(300)
        service.pauseSession(now: t1)
        
        guard let data2 = defaults.data(forKey: AppGroupConfig.widgetSnapshotKey),
              let snap2 = try? JSONDecoder().decode(WidgetReadingSnapshot.self, from: data2) else {
            fatalError("Widget snapshot should be persisted on pause")
        }
        assert(snap2.state == .paused, "Snapshot state should be paused")
        assert(snap2.accumulatedActiveSeconds == 300, "Accumulated active seconds should be 300, got \(snap2.accumulatedActiveSeconds)")
        assert(snap2.isPaused, "isPaused should be true")
        assert(snap2.virtualTimerStartDate == nil, "virtualTimerStartDate must be nil when paused")
        
        // Finish session
        _ = service.finishSession(now: t1.addingTimeInterval(60))
        guard let data3 = defaults.data(forKey: AppGroupConfig.widgetSnapshotKey),
              let snap3 = try? JSONDecoder().decode(WidgetReadingSnapshot.self, from: data3) else {
            fatalError("Widget snapshot should be persisted on finish")
        }
        assert(snap3.state == .idle, "Snapshot state should return to idle after finish")
    }
    
    private static func testWidgetActionDebounceProtection() {
        let defaultsSuite = "test_widget_debounce_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        let service = ReadingTimerService(userDefaults: defaults)
        
        let t0 = Date(timeIntervalSince1970: 2000)
        service.startSession(bookId: UUID(), bookTitle: "Debounce Book", now: t0)
        assert(service.isRunning, "Timer should be running")
        
        // Tap 1 from widget at t0 + 10s: pauses
        let t1 = t0.addingTimeInterval(10)
        service.toggleTimerFromWidget(now: t1)
        assert(service.isPaused, "Session should be paused after first tap")
        
        // Tap 2 from widget immediately at t1 + 0.1s (< 0.3s debounce): must be ignored!
        let t2 = t1.addingTimeInterval(0.1)
        service.toggleTimerFromWidget(now: t2)
        assert(service.isPaused, "Rapid duplicate tap within 100ms must be discarded; session must remain paused")
        
        // Tap 3 after 0.5s: resumes properly
        let t3 = t1.addingTimeInterval(0.5)
        service.toggleTimerFromWidget(now: t3)
        assert(service.isRunning, "Session should resume after debounce window")
    }
    
    private static func testTodayProgressCalculation() {
        let snapshot = TodayProgressSnapshot(
            todaySeconds: 1350,
            dailyGoalSeconds: 1800,
            sessionCountToday: 2,
            currentStreakDays: 5
        )
        assert(snapshot.progressFraction == 0.75, "1350s / 1800s should equal 0.75 (75%)")
        
        let widgetSnap = WidgetReadingSnapshot(
            todaySeconds: 2700,
            dailyGoalSeconds: 1800
        )
        assert(widgetSnap.todayProgressFraction == 1.0, "Progress fraction must be clamped to max 1.0")
    }
}

