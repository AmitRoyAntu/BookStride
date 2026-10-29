//
//  WeeklyTrendChart.swift
//  BookStride
//
//  Swift Charts area and line chart displaying weekly reading momentum.
//

import SwiftUI
import Charts

public struct WeeklyTrendChart: View {
    public var points: [WeeklyReadingPoint]
    
    public init(points: [WeeklyReadingPoint]) {
        self.points = points
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weekly Trend")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                Text("Total reading minutes per week over past 8 weeks")
                    .font(.caption)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            
            if points.allSatisfy({ $0.minutes == 0 }) {
                Text("No weekly trend data yet.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Week", point.label),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [BookStrideTheme.forestGreen.opacity(0.35), BookStrideTheme.forestGreen.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)
                        
                        LineMark(
                            x: .value("Week", point.label),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(BookStrideTheme.forestGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                        
                        PointMark(
                            x: .value("Week", point.label),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(BookStrideTheme.forestGreen)
                        .symbolSize(36)
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
                .frame(height: 200)
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
}

