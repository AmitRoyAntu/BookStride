//
//  ReadingLiveActivityView.swift
//  BookStride
//
//  Live Activity Lock Screen banner presentation for active BookStride reading sessions.
//  Renders dynamic elapsed timer via ActivityKit, daily goal progress ring,
//  and interactive controls (pause/resume/finish) via App Intents.
//

import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif
#if canImport(AppIntents)
import AppIntents
#endif

#if canImport(ActivityKit) && canImport(WidgetKit)
@available(iOS 16.1, macOS 13.0, *)
public struct ReadingLiveActivityWidget: Widget {
    public let kind: String = "BookStrideReadingLiveActivity"
    
    public init() {}
    
    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            ReadingLiveActivityBannerView(context: context)
                .widgetURL(URL(string: "bookstride://timer"))
        } dynamicIsland: { context in
            // Dynamic Island placeholder (iPadOS does not have a Dynamic Island, but protocol requires conformance)
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.bookTitle, systemImage: "book.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color(hex: "2D5A43"))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text(Formatters.formatDuration(seconds: context.state.accumulatedSeconds, style: .timer))
                            .font(.caption.monospacedDigit())
                    } else {
                        let startDate = Date().addingTimeInterval(-Double(context.state.accumulatedSeconds))
                        Text(timerInterval: startDate...Date.distantFuture, pauseTime: nil, countsDown: false)
                            .font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isPaused ? "Paused" : "Reading Session")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        #if canImport(AppIntents)
                        if #available(iOS 17.0, *) {
                            Button(intent: ToggleReadingTimerIntent()) {
                                Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hex: "2D5A43"))
                        }
                        #endif
                    }
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .foregroundColor(Color(hex: "2D5A43"))
            } compactTrailing: {
                if context.state.isPaused {
                    Text(Formatters.formatDuration(seconds: context.state.accumulatedSeconds, style: .timer))
                        .font(.caption2.monospacedDigit())
                } else {
                    let startDate = Date().addingTimeInterval(-Double(context.state.accumulatedSeconds))
                    Text(timerInterval: startDate...Date.distantFuture, pauseTime: nil, countsDown: false)
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: "book.fill")
                    .foregroundColor(Color(hex: "2D5A43"))
            }
        }
    }
}

@available(iOS 16.1, macOS 13.0, *)
struct ReadingLiveActivityBannerView: View {
    let context: ActivityViewContext<ReadingActivityAttributes>
    
    private var progressFraction: Double {
        guard context.state.dailyGoalSeconds > 0 else { return 0 }
        let currentSeconds = context.state.todaySeconds + (context.state.isPaused ? 0 : context.state.accumulatedSeconds)
        return min(1.0, max(0.0, Double(currentSeconds) / Double(context.state.dailyGoalSeconds)))
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Book Icon / Status indicator
            ZStack {
                Circle()
                    .fill(Color(hex: "2D5A43").opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "book.fill")
                    .font(.title3)
                    .foregroundColor(Color(hex: "2D5A43"))
            }
            
            // Middle: Book Title, Author, Dynamic Ticking Timer
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.bookTitle.isEmpty ? "Currently Reading" : context.state.bookTitle)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundColor(Color(hex: "1C2A24"))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if context.state.isPaused {
                        Text(Formatters.formatDuration(seconds: context.state.accumulatedSeconds, style: .timer))
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                            .foregroundColor(Color(hex: "6A7B76"))
                        
                        Text("• Paused")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(hex: "B78103"))
                    } else {
                        let startDate = Date().addingTimeInterval(-Double(context.state.accumulatedSeconds))
                        Text(timerInterval: startDate...Date.distantFuture, pauseTime: nil, countsDown: false)
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                            .foregroundColor(Color(hex: "2D5A43"))
                        
                        Text("• Reading")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(Color(hex: "2D5A43"))
                    }
                }
                
                // Progress towards daily goal
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(hex: "E4DFD3"))
                                .frame(height: 4)
                            Capsule()
                                .fill(Color(hex: "2D5A43"))
                                .frame(width: max(4, geo.size.width * progressFraction), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text("\(Int(progressFraction * 100))% goal")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "6A7B76"))
                }
                .frame(maxWidth: 180)
            }
            
            Spacer()
            
            // Right: Interactive Controls (Pause/Resume & Finish)
            #if canImport(AppIntents)
            if #available(iOS 17.0, *) {
                HStack(spacing: 8) {
                    Button(intent: ToggleReadingTimerIntent()) {
                        Image(systemName: context.state.isPaused ? "play.fill" : "pause.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: "2D5A43"))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(intent: FinishReadingActivityIntent()) {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 38, height: 38)
                            .background(Color(hex: "E4DFD3"))
                            .foregroundColor(Color(hex: "1C2A24"))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            #endif
        }
        .padding(16)
        .background(Color(hex: "F9F8F5"))
    }
}
#endif
