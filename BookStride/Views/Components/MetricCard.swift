//
//  MetricCard.swift
//  BookStride
//
//  Display card for reading statistics and highlights.
//

import SwiftUI

public struct MetricCard: View {
    public var title: String
    public var value: String
    public var subtitle: String?
    public var iconName: String
    public var accentColor: Color
    
    public init(
        title: String,
        value: String,
        subtitle: String? = nil,
        iconName: String,
        accentColor: Color = BookStrideTheme.forestGreen
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.iconName = iconName
        self.accentColor = accentColor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                Spacer()
                Image(systemName: iconName)
                    .font(.body)
                    .foregroundColor(accentColor)
            }
            
            Text(value)
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundColor(BookStrideTheme.deepCharcoal)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundColor(BookStrideTheme.mutedSlate)
                    .lineLimit(1)
            }
        }
        .padding(LayoutConstants.cardInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .BookStrideCardStyle(cornerRadius: LayoutConstants.cardCornerRadius)
    }
}

