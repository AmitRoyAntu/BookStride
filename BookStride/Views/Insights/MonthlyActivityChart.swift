//
//  MonthlyActivityChart.swift
//  BookStride
//
//  Swift Charts bar chart showing monthly reading volume in hours.
//

import SwiftUI
import Charts

public struct MonthlyActivityChart: View {
    public var points: [MonthlyReadingPoint]
    
    public init(points: [MonthlyReadingPoint]) {
        self.points = points
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Volume")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                Text("Total hours read over the past 6 months")
                    .font(.caption)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            
            if points.allSatisfy({ $0.hours == 0 }) {
                Text("No monthly data recorded yet.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Month", point.label),
                            y: .value("Hours", point.hours)
                        )
                        .foregroundStyle(BookStrideTheme.forestGreen)
                        .cornerRadius(6)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(BookStrideTheme.borderLight)
                        AxisValueLabel {
                            if let h = value.as(Double.self) {
                                Text("\(String(format: "%.1f", h))h")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
}

