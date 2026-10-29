//
//  ReadingCalendarHeatmap.swift
//  BookStride
//
//  Calendar heatmap displaying daily reading consistency across the current month.
//

import SwiftUI

public struct ReadingCalendarHeatmap: View {
    public var points: [HeatmapDayPoint]
    @State private var selectedPoint: HeatmapDayPoint?
    
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    public init(points: [HeatmapDayPoint]) {
        self.points = points
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading Habit Heatmap")
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Text("Daily reading consistency for this month")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
                Spacer()
                
                // Legend
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                    ForEach(0...4, id: \.self) { lvl in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intensityColor(lvl))
                            .frame(width: 10, height: 10)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundColor(BookStrideTheme.mutedSlate)
                }
            }
            
            // Weekday Header
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundColor(BookStrideTheme.mutedSlate)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Grid
            LazyVGrid(columns: columns, spacing: 8) {
                // Leading padding days to align month start with weekday
                if let first = points.first {
                    let firstWeekday = Calendar.current.component(.weekday, from: first.date)
                    ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                        Color.clear.frame(height: 36)
                    }
                }
                
                ForEach(points) { point in
                    let dayNum = Calendar.current.component(.day, from: point.date)
                    let isSelected = selectedPoint?.id == point.id
                    
                    Button {
                        selectedPoint = point
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(intensityColor(point.intensity))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? BookStrideTheme.deepCharcoal : Color.clear, lineWidth: 1.5)
                                )
                            
                            Text("\(dayNum)")
                                .font(.caption2.weight(point.intensity >= 3 ? .bold : .regular))
                                .foregroundColor(point.intensity >= 3 ? .white : BookStrideTheme.deepCharcoal)
                        }
                        .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Inspection readout
            if let selected = selectedPoint {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(BookStrideTheme.forestGreen)
                    Text("\(Formatters.formatDate(selected.date, style: .fullDate)): \(selected.minutes) minutes read")
                        .font(.caption)
                        .foregroundColor(BookStrideTheme.deepCharcoal)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
    
    private func intensityColor(_ level: Int) -> Color {
        switch level {
        case 0:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(white: 0.22, alpha: 1.0)
                    : UIColor(red: 216/255, green: 206/255, blue: 191/255, alpha: 0.35)
            })
        case 1:
            return BookStrideTheme.forestGreenLight.opacity(0.35)
        case 2:
            return BookStrideTheme.forestGreenLight.opacity(0.65)
        case 3:
            return BookStrideTheme.forestGreen.opacity(0.85)
        case 4:
            return BookStrideTheme.forestGreen
        default:
            return Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(white: 0.22, alpha: 1.0)
                    : UIColor(red: 216/255, green: 206/255, blue: 191/255, alpha: 0.35)
            })
        }
    }
}

