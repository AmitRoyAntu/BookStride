//
//  DailyProgressCard.swift
//  BookStride
//
//  Prominent dashboard card showing daily goal ring, streak, and sessions count.
//

import SwiftUI

public struct DailyProgressCard: View {
    public var todaySeconds: Int
    public var goalSeconds: Int
    public var sessionCountToday: Int
    public var currentStreakDays: Int
    
    public init(
        todaySeconds: Int,
        goalSeconds: Int = 1800,
        sessionCountToday: Int = 0,
        currentStreakDays: Int = 0
    ) {
        self.todaySeconds = todaySeconds
        self.goalSeconds = max(60, goalSeconds)
        self.sessionCountToday = sessionCountToday
        self.currentStreakDays = currentStreakDays
    }
    
    private var progress: Double {
        Double(todaySeconds) / Double(goalSeconds)
    }
    
    private var remainingMinutes: Int {
        let diff = goalSeconds - todaySeconds
        return max(0, Int(ceil(Double(diff) / 60.0)))
    }
    
    private var isGoalMet: Bool {
        todaySeconds >= goalSeconds
    }
    
    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 28) {
                progressRing
                metricsColumn
                Spacer()
            }
            VStack(alignment: .leading, spacing: 20) {
                progressRing
                    .frame(maxWidth: .infinity, alignment: .center)
                metricsColumn
            }
        }
        .padding(24)
        .BookStrideCardStyle(cornerRadius: LayoutConstants.cardCornerRadius)
    }
    
    private var progressRing: some View {
        CircularProgressRing(
            progress: progress,
            lineWidth: 14,
            strokeColor: isGoalMet ? BookStrideTheme.forestGreen : BookStrideTheme.forestGreenLight,
            trackColor: BookStrideTheme.warmBeige.opacity(0.35)
        ) {
            VStack(spacing: 4) {
                Text(Formatters.formatDuration(seconds: todaySeconds, style: .short))
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                
                Text("of \(goalSeconds / 60)m goal")
                    .font(.caption2)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
        }
        .frame(width: 140, height: 140)
    }
    
    private var metricsColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Goal message
            VStack(alignment: .leading, spacing: 4) {
                if isGoalMet {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(BookStrideTheme.forestGreen)
                        Text("Daily Goal Completed")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(BookStrideTheme.forestGreen)
                    }
                    Text("Excellent reading discipline today.")
                        .font(.subheadline)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                } else {
                    Text("\(remainingMinutes) min remaining")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("Keep your reading momentum going.")
                        .font(.subheadline)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            
            Divider()
            
            // Stat Pills (Streak & Sessions)
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.callout)
                        .foregroundColor(BookStrideTheme.streakAmber)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(currentStreakDays) \(currentStreakDays == 1 ? "day" : "days")")
                            .font(.callout.weight(.bold))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Text("Streak")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.callout)
                        .foregroundColor(BookStrideTheme.forestGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(sessionCountToday) \(sessionCountToday == 1 ? "session" : "sessions")")
                            .font(.callout.weight(.bold))
                            .foregroundColor(BookStrideTheme.deepCharcoal)
                        Text("Today")
                            .font(.caption2)
                            .foregroundColor(BookStrideTheme.mutedSlate)
                    }
                }
            }
        }
    }
}

