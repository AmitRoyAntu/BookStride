//
//  DailyReadingBarChart.swift
//  BookStride
//
//  Swift Charts bar chart showing daily reading duration and goal threshold line.
//

import SwiftUI
import Charts

public struct DailyReadingBarChart: View {
    public var points: [DailyReadingPoint]
    public var goalMinutes: Double
    
    public init(points: [DailyReadingPoint], goalMinutes: Double = 30.0) {
        self.points = points
        self.goalMinutes = goalMinutes
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Reading Activity")
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("Last 7 days with \(Int(goalMinutes))m goal line")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                Spacer()
            }
            
            if points.allSatisfy({ $0.minutes == 0 }) {
                Text("No reading time recorded in the last 7 days.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Daily Goal Rule Line
                    RuleMark(y: .value("Goal", goalMinutes))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(BookStrideTheme.streakAmber)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal (\(Int(goalMinutes))m)")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(BookStrideTheme.streakAmber)
                        }
                    
                    // Daily Bars
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(
                            point.metGoal
                            ? BookStrideTheme.forestGreen
                            : (point.minutes > 0 ? BookStrideTheme.forestGreenLight : BookStrideTheme.borderLight)
                        )
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(date, format: .dateTime.weekday(.abbreviated).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(BookStrideTheme.borderLight)
                        AxisValueLabel {
                            if let min = value.as(Double.self) {
                                Text("\(Int(min))m")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
}

