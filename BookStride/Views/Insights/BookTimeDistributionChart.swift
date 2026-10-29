//
//  BookTimeDistributionChart.swift
//  BookStride
//
//  Horizontal breakdown showing reading time distribution across books.
//

import SwiftUI

public struct BookTimeDistributionChart: View {
    public var distribution: [BookTimePoint]
    
    public init(distribution: [BookTimePoint]) {
        self.distribution = distribution
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Time Spent per Book")
                    .font(.system(.headline, design: .serif, weight: .bold))
                    .foregroundColor(BookStrideTheme.deepCharcoal)
                Text("Books receiving the most dedicated reading attention")
                    .font(.caption)
                    .foregroundColor(BookStrideTheme.mutedSlate)
            }
            
            if distribution.isEmpty {
                Text("No book sessions recorded for this period.")
                    .font(.subheadline)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    ForEach(distribution) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(BookStrideTheme.deepCharcoal)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(Formatters.formatDuration(seconds: Int(item.minutes * 60), style: .short))
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(BookStrideTheme.forestGreen)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(BookStrideTheme.warmBeige.opacity(0.35))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(BookStrideTheme.bookCoverColors[item.coverColorHex] ?? BookStrideTheme.forestGreen)
                                        .frame(width: max(8, geo.size.width * CGFloat(item.percentage)), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(20)
        .BookStrideCardStyle()
    }
}

