//
//  BookStrideTimerWidget.swift
//  BookStride
//
//  Configurable minimal Reading Timer widget for iPadOS.
//  Implements Small (timer + action) and Medium (timer + today's progress + action) layouts.
//

import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(AppIntents)
import AppIntents
#endif

public struct ReadingTimerTimelineEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetReadingSnapshot
    
    public init(date: Date = Date(), snapshot: WidgetReadingSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }
}

#if canImport(WidgetKit)
public struct ReadingTimerTimelineProvider: TimelineProvider {
    public typealias Entry = ReadingTimerTimelineEntry
    
    public init() {}
    
    public func placeholder(in context: Context) -> ReadingTimerTimelineEntry {
        let sample = WidgetReadingSnapshot(
            state: .active,
            sessionId: UUID(),
            bookTitle: "Atomic Habits",
            startedAt: Date().addingTimeInterval(-1500),
            accumulatedActiveSeconds: 1500,
            todaySeconds: 2700,
            dailyGoalSeconds: 1800,
            isPaused: false
        )
        return ReadingTimerTimelineEntry(date: Date(), snapshot: sample)
    }
    
    public func getSnapshot(in context: Context, completion: @escaping (ReadingTimerTimelineEntry) -> Void) {
        let snapshot = loadSnapshot()
        completion(ReadingTimerTimelineEntry(date: Date(), snapshot: snapshot))
    }
    
    public func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingTimerTimelineEntry>) -> Void) {
        let snapshot = loadSnapshot()
        let currentEntry = ReadingTimerTimelineEntry(date: Date(), snapshot: snapshot)
        
        // Refresh every 15 minutes, or upon interactive AppIntent trigger
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadSnapshot() -> WidgetReadingSnapshot {
        let defaults = AppGroupConfig.sharedDefaults
        if let data = defaults.data(forKey: AppGroupConfig.widgetSnapshotKey),
           let snapshot = try? JSONDecoder().decode(WidgetReadingSnapshot.self, from: data) {
            return snapshot
        }
        
        // Fallback: inspect raw active session state
        if let stateData = defaults.data(forKey: AppGroupConfig.activeStateKey),
           let state = try? JSONDecoder().decode(ActiveSessionState.self, from: stateData) {
            let sState: WidgetSessionState = state.isPaused ? .paused : .active
            return WidgetReadingSnapshot(
                state: sState,
                sessionId: state.sessionId,
                bookId: state.bookId,
                bookTitle: state.bookTitle,
                startedAt: state.startedAt,
                lastResumedAt: state.lastResumedAt,
                lastPausedAt: state.lastPausedAt,
                accumulatedActiveSeconds: state.accumulatedActiveSeconds,
                isPaused: state.isPaused
            )
        }
        
        return WidgetReadingSnapshot()
    }
}

// MARK: - Widget Root Configuration

public struct BookStrideTimerWidget: Widget {
    public static let kind: String = "BookStrideReadingTimerWidget"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ReadingTimerTimelineProvider()) { entry in
            BookStrideTimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Reading Timer")
        .description("Track your active reading focus session and today's reading progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
#endif

// MARK: - Entry View

public struct BookStrideTimerWidgetEntryView: View {
    public var entry: ReadingTimerTimelineEntry
    #if canImport(WidgetKit)
    @Environment(\.widgetFamily) var family
    #endif
    
    public init(entry: ReadingTimerTimelineEntry) {
        self.entry = entry
    }
    
    public var body: some View {
        #if canImport(WidgetKit)
        Group {
            switch family {
            case .systemSmall:
                SmallReadingTimerWidgetView(snapshot: entry.snapshot)
            case .systemMedium:
                MediumReadingTimerWidgetView(snapshot: entry.snapshot)
            default:
                SmallReadingTimerWidgetView(snapshot: entry.snapshot)
            }
        }
        .widgetURL(URL(string: AppGroupConfig.widgetURLString))
        #else
        SmallReadingTimerWidgetView(snapshot: entry.snapshot)
        #endif
    }
}

// MARK: - Small Layout (Timer & Action Button)

public struct SmallReadingTimerWidgetView: View {
    public let snapshot: WidgetReadingSnapshot
    @Environment(\.colorScheme) var colorScheme
    
    public init(snapshot: WidgetReadingSnapshot) {
        self.snapshot = snapshot
    }
    
    private var isDark: Bool {
        colorScheme == .dark
    }
    
    public var body: some View {
        ZStack {
            widgetBackground
            
            VStack(alignment: .leading, spacing: 6) {
                // Top Header: Branding + Status Dot
                HStack(spacing: 5) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(BookStrideTheme.forestGreen)
                    
                    Text("BOOKSTRIDE")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                    
                    Spacer()
                    
                    statusBadge
                }
                
                // Book Title
                Text(snapshot.state == .idle ? "Ready to Read" : snapshot.bookTitle)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineLimit(1)
                
                Spacer(minLength: 2)
                
                // Live Timer Display
                timerDisplay
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer(minLength: 2)
                
                // Overlay Action Button
                HStack {
                    actionButton
                    Spacer()
                }
            }
            .padding(14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
    
    @ViewBuilder
    private var timerDisplay: some View {
        switch snapshot.state {
        case .active:
            if let vStart = snapshot.virtualTimerStartDate {
                Text(vStart, style: .timer)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(Formatters.formatDuration(seconds: snapshot.accumulatedActiveSeconds, style: .timer))
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
            }
        case .paused:
            Text(Formatters.formatDuration(seconds: snapshot.frozenElapsedSeconds, style: .timer))
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(BookStrideTheme.streakAmber)
                .lineLimit(1)
        case .idle, .finished:
            Text("00:00")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(BookStrideTheme.mutedSlate.opacity(0.6))
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(snapshot.state.label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
    }
    
    private var statusColor: Color {
        switch snapshot.state {
        case .active: return BookStrideTheme.forestGreen
        case .paused: return BookStrideTheme.streakAmber
        case .idle, .finished: return BookStrideTheme.mutedSlate
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        #if canImport(AppIntents)
        if #available(iOS 17.0, *) {
            Button(intent: ToggleReadingTimerIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: actionButtonIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(actionButtonText)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(actionButtonTextColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(actionButtonBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionButtonVoiceOverLabel)
        } else {
            fallbackActionButton
        }
        #else
        fallbackActionButton
        #endif
    }
    
    private var fallbackActionButton: some View {
        HStack(spacing: 6) {
            Image(systemName: actionButtonIcon)
                .font(.system(size: 11, weight: .bold))
            Text(actionButtonText)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(actionButtonTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(actionButtonBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BookStrideTheme.borderLight, lineWidth: 1)
        )
    }
    
    private var actionButtonIcon: String {
        switch snapshot.state {
        case .active: return "pause.fill"
        case .paused: return "play.fill"
        case .idle, .finished: return "play.fill"
        }
    }
    
    private var actionButtonText: String {
        switch snapshot.state {
        case .active: return "Pause"
        case .paused: return "Resume"
        case .idle, .finished: return "Start"
        }
    }
    
    private var actionButtonTextColor: Color {
        switch snapshot.state {
        case .active: return BookStrideTheme.deepCharcoal
        case .paused: return BookStrideTheme.streakAmber
        case .idle, .finished: return BookStrideTheme.forestGreen
        }
    }
    
    private var actionButtonBackground: Color {
        isDark ? Color.white.opacity(0.1) : Color.white
    }
    
    private var actionButtonVoiceOverLabel: String {
        switch snapshot.state {
        case .active: return "Pause reading timer"
        case .paused: return "Resume reading timer"
        case .idle, .finished: return "Start reading session"
        }
    }
    
    private var widgetBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(BookStrideTheme.warmIvory)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
    }
    
    private var accessibilitySummary: String {
        let title = snapshot.state == .idle ? "No active session" : snapshot.bookTitle
        let state = snapshot.state.label
        let elapsed = Formatters.formatDuration(seconds: snapshot.accumulatedActiveSeconds, style: .short)
        return "Bookstride reading timer. Book: \(title). State: \(state). Elapsed time: \(elapsed)."
    }
}

// MARK: - Medium Layout (Timer, Today's Progress, & Action Button)

public struct MediumReadingTimerWidgetView: View {
    public let snapshot: WidgetReadingSnapshot
    @Environment(\.colorScheme) var colorScheme
    
    public init(snapshot: WidgetReadingSnapshot) {
        self.snapshot = snapshot
    }
    
    private var isDark: Bool {
        colorScheme == .dark
    }
    
    public var body: some View {
        ZStack {
            widgetBackground
            
            HStack(spacing: 16) {
                // Left Column: Active Timer & Session Controls
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                        
                        Text("BOOKSTRIDE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.4)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        
                        Spacer()
                        
                        statusBadge
                    }
                    
                    Text(snapshot.state == .idle ? "Ready to Read" : snapshot.bookTitle)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                        .lineLimit(1)
                    
                    Spacer(minLength: 2)
                    
                    // Large Monospaced Timer
                    timerDisplay
                    
                    Spacer(minLength: 2)
                    
                    // Subtly Styled Overlay Action Button
                    actionButton
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Vertical Divider
                Rectangle()
                    .fill(BookStrideTheme.borderLight)
                    .frame(width: 1)
                    .padding(.vertical, 4)
                
                // Right Column: Today's Reading Progress
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("TODAY'S PROGRESS")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                        Spacer()
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11))
                            .foregroundColor(BookStrideTheme.forestGreen)
                    }
                    
                    // Today duration
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Formatters.formatDuration(seconds: snapshot.todaySeconds, style: .short))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        
                        Text("Goal: \(snapshot.dailyGoalSeconds / 60)m (\(Int(snapshot.todayProgressFraction * 100))%)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(BookStrideTheme.borderLight)
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(BookStrideTheme.forestGreen)
                                .frame(width: max(6, geo.size.width * CGFloat(snapshot.todayProgressFraction)), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    Spacer(minLength: 2)
                    
                    // Supporting hint
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 9))
                        Text("Tap to open timer")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(BookStrideTheme.mutedSlate.opacity(0.8))
                }
                .frame(width: 128)
            }
            .padding(14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumAccessibilitySummary)
    }
    
    @ViewBuilder
    private var timerDisplay: some View {
        switch snapshot.state {
        case .active:
            if let vStart = snapshot.virtualTimerStartDate {
                Text(vStart, style: .timer)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(Formatters.formatDuration(seconds: snapshot.accumulatedActiveSeconds, style: .timer))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
            }
        case .paused:
            Text(Formatters.formatDuration(seconds: snapshot.frozenElapsedSeconds, style: .timer))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(BookStrideTheme.streakAmber)
                .lineLimit(1)
        case .idle, .finished:
            Text("00:00")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(BookStrideTheme.mutedSlate.opacity(0.6))
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(snapshot.state.label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.12))
        )
    }
    
    private var statusColor: Color {
        switch snapshot.state {
        case .active: return BookStrideTheme.forestGreen
        case .paused: return BookStrideTheme.streakAmber
        case .idle, .finished: return BookStrideTheme.mutedSlate
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        #if canImport(AppIntents)
        if #available(iOS 17.0, *) {
            Button(intent: ToggleReadingTimerIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: actionButtonIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(actionButtonText)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(actionButtonTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(actionButtonBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(BookStrideTheme.borderLight, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionButtonVoiceOverLabel)
        } else {
            fallbackActionButton
        }
        #else
        fallbackActionButton
        #endif
    }
    
    private var fallbackActionButton: some View {
        HStack(spacing: 6) {
            Image(systemName: actionButtonIcon)
                .font(.system(size: 11, weight: .bold))
            Text(actionButtonText)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(actionButtonTextColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(actionButtonBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(BookStrideTheme.borderLight, lineWidth: 1)
        )
    }
    
    private var actionButtonIcon: String {
        switch snapshot.state {
        case .active: return "pause.fill"
        case .paused: return "play.fill"
        case .idle, .finished: return "play.fill"
        }
    }
    
    private var actionButtonText: String {
        switch snapshot.state {
        case .active: return "Pause"
        case .paused: return "Resume"
        case .idle, .finished: return "Start"
        }
    }
    
    private var actionButtonTextColor: Color {
        switch snapshot.state {
        case .active: return BookStrideTheme.deepCharcoal
        case .paused: return BookStrideTheme.streakAmber
        case .idle, .finished: return BookStrideTheme.forestGreen
        }
    }
    
    private var actionButtonBackground: Color {
        isDark ? Color.white.opacity(0.1) : Color.white
    }
    
    private var actionButtonVoiceOverLabel: String {
        switch snapshot.state {
        case .active: return "Pause reading timer"
        case .paused: return "Resume reading timer"
        case .idle, .finished: return "Start reading session"
        }
    }
    
    private var widgetBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(BookStrideTheme.warmIvory)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
    }
    
    private var mediumAccessibilitySummary: String {
        let title = snapshot.state == .idle ? "No active session" : snapshot.bookTitle
        let state = snapshot.state.label
        let today = Formatters.formatDuration(seconds: snapshot.todaySeconds, style: .short)
        return "Bookstride reading timer for \(title). Status: \(state). Today's reading total: \(today)."
    }
}
