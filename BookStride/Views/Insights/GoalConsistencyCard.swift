//
//  GoalConsistencyCard.swift
//  BookStride
//
//  Swift Charts and metric card visualizing daily goal completion rate and streak discipline.
//

import SwiftUI
import Charts

public struct GoalConsistencyCard: View {
    public var summary: InsightsAnalyticsSummary
    public var dailyPoints: [DailyReadingPoint]
    public var dailyGoalMinutes: Int
    
    public init(
        summary: InsightsAnalyticsSummary,
        dailyPoints: [DailyReadingPoint],
        dailyGoalMinutes: Int = 30
    ) {
        self.summary = summary
        self.dailyPoints = dailyPoints
        self.dailyGoalMinutes = dailyGoalMinutes
    }
    
    private var daysWithGoalMet: Int {
        dailyPoints.filter { $0.metGoal }.count
    }
    
    private var daysTracked: Int {
        dailyPoints.count
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Goal Completion")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                Text("Consistency in reaching your \(dailyGoalMinutes)-minute daily target")
                    .font(.caption)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            
            // Metrics Row
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(daysWithGoalMet) of \(daysTracked) Days")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.forestGreen)
                    Text("Goal Hit Rate")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Divider().frame(height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.formatPercentage(summary.goalCompletionRate))
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("Consistency Rate")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Divider().frame(height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(summary.currentStreak) Days")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.streakAmber)
                    Text("Current Streak")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
            }
            
            // Progress Bar Distribution
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BookStrideTheme.borderLight.opacity(0.6))
                        .frame(height: 10)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BookStrideTheme.forestGreen)
                        .frame(width: max(6, geo.size.width * CGFloat(min(1.0, summary.goalCompletionRate))), height: 10)
                }
            }
            .frame(height: 10)
            
            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(BookStrideTheme.forestGreen)
                        .frame(width: 8, height: 8)
                    Text("Goal Met (\(daysWithGoalMet)d)")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(BookStrideTheme.borderLight)
                        .frame(width: 8, height: 8)
                    Text("Below Goal (\(max(0, daysTracked - daysWithGoalMet))d)")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
}
