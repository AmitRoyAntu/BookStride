//
//  CircularProgressRing.swift
//  BookStride
//
//  Animated circular progress ring for daily reading goals and completion rates.
//

import SwiftUI

public struct CircularProgressRing<CenterContent: View>: View {
    public var progress: Double // 0.0 to 1.0+
    public var lineWidth: CGFloat = 14
    public var strokeColor: Color = BookStrideTheme.forestGreen
    public var trackColor: Color = BookStrideTheme.warmBeige.opacity(0.35)
    public var centerContent: () -> CenterContent
    
    public init(
        progress: Double,
        lineWidth: CGFloat = 14,
        strokeColor: Color = BookStrideTheme.forestGreen,
        trackColor: Color = BookStrideTheme.warmBeige.opacity(0.35),
        @ViewBuilder centerContent: @escaping () -> CenterContent
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.strokeColor = strokeColor
        self.trackColor = trackColor
        self.centerContent = centerContent
    }
    
    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Progress Stroke
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    strokeColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: -90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            
            centerContent()
        }
        .padding(lineWidth / 2)
    }
}

