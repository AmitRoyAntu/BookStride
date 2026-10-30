//
//  ColorTheme.swift
//  BookStride
//
//  Adaptive design system for the BookStride reading journal aesthetic.
//  Fully supports Light and Dark modes with high-contrast, comfortable typography
//  across both iPadOS and macOS.
//

import SwiftUI
#if canImport(UIKit)
import UIKit

private func dynamicAdaptiveColor(
    lightRed: Double, lightGreen: Double, lightBlue: Double,
    darkRed: Double, darkGreen: Double, darkBlue: Double
) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: darkRed/255, green: darkGreen/255, blue: darkBlue/255, alpha: 1.0)
            : UIColor(red: lightRed/255, green: lightGreen/255, blue: lightBlue/255, alpha: 1.0)
    })
}
#elseif canImport(AppKit)
import AppKit

private func dynamicAdaptiveColor(
    lightRed: Double, lightGreen: Double, lightBlue: Double,
    darkRed: Double, darkGreen: Double, darkBlue: Double
) -> Color {
    Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: darkRed/255, green: darkGreen/255, blue: darkBlue/255, alpha: 1.0)
            : NSColor(red: lightRed/255, green: lightGreen/255, blue: lightBlue/255, alpha: 1.0)
    }))
}
#else
private func dynamicAdaptiveColor(
    lightRed: Double, lightGreen: Double, lightBlue: Double,
    darkRed: Double, darkGreen: Double, darkBlue: Double
) -> Color {
    Color(red: lightRed/255, green: lightGreen/255, blue: lightBlue/255)
}
#endif

public enum BookStrideTheme {
    // Dynamic Primary Text: deep charcoal in light mode, crisp warm cream-white in dark mode
    public static let deepCharcoal = dynamicAdaptiveColor(
        lightRed: 35, lightGreen: 33, lightBlue: 30,
        darkRed: 245, darkGreen: 243, darkBlue: 238
    )
    
    // Dynamic Secondary Text: muted slate in light mode, soft readable warm gray in dark mode
    public static let mutedSlate = dynamicAdaptiveColor(
        lightRed: 110, lightGreen: 106, lightBlue: 98,
        darkRed: 185, darkGreen: 180, darkBlue: 172
    )
    
    // Dynamic Card Surface: pure white in light mode, warm charcoal surface in dark mode
    public static let cardLight = dynamicAdaptiveColor(
        lightRed: 255, lightGreen: 255, lightBlue: 255,
        darkRed: 38, darkGreen: 36, darkBlue: 33
    )
    public static let cardDark = Color(red: 38/255, green: 36/255, blue: 33/255)
    
    // Dynamic Card Border: soft warm sand in light mode, subtle dark border in dark mode
    public static let borderLight = dynamicAdaptiveColor(
        lightRed: 232, lightGreen: 228, lightBlue: 220,
        darkRed: 58, darkGreen: 55, darkBlue: 50
    )
    public static let borderDark = Color(red: 58/255, green: 55/255, blue: 50/255)
    
    // Dynamic Background: warm ivory in light mode, deep obsidian/charcoal in dark mode
    public static let warmIvory = dynamicAdaptiveColor(
        lightRed: 249, lightGreen: 248, lightBlue: 245,
        darkRed: 24, darkGreen: 23, darkBlue: 21
    )
    public static let darkCharcoal = Color(red: 24/255, green: 23/255, blue: 21/255)
    
    // Dynamic Accent: muted forest green in light mode, vibrant sage/forest green in dark mode
    public static let forestGreen = dynamicAdaptiveColor(
        lightRed: 45, lightGreen: 90, lightBlue: 67,
        darkRed: 88, darkGreen: 158, darkBlue: 118
    )
    
    public static let forestGreenLight = dynamicAdaptiveColor(
        lightRed: 75, lightGreen: 130, lightBlue: 100,
        darkRed: 115, darkGreen: 185, darkBlue: 145
    )
    
    // Secondary accent: warm beige / sand
    public static let warmBeige = dynamicAdaptiveColor(
        lightRed: 216, lightGreen: 206, lightBlue: 191,
        darkRed: 75, darkGreen: 70, darkBlue: 62
    )
    public static let sandDark = Color(red: 70/255, green: 65/255, blue: 57/255)
    
    // High-contrast text helpers
    public static let lightText = Color(red: 245/255, green: 243/255, blue: 238/255)
    public static let lightMutedText = Color(red: 185/255, green: 180/255, blue: 172/255)
    
    // Streak amber
    public static let streakAmber = dynamicAdaptiveColor(
        lightRed: 217, lightGreen: 130, lightBlue: 43,
        darkRed: 240, darkGreen: 155, darkBlue: 65
    )
    
    // Book cover palette presets
    public static let bookCoverColors: [String: Color] = [
        "forest": Color(red: 45/255, green: 90/255, blue: 67/255),
        "terracotta": Color(red: 184/255, green: 91/255, blue: 71/255),
        "navy": Color(red: 41/255, green: 67/255, blue: 92/255),
        "slate": Color(red: 88/255, green: 96/255, blue: 105/255),
        "burgundy": Color(red: 122/255, green: 46/255, blue: 60/255),
        "sage": Color(red: 104/255, green: 133/255, blue: 112/255),
        "gold": Color(red: 191/255, green: 147/255, blue: 63/255),
        "plum": Color(red: 94/255, green: 61/255, blue: 90/255)
    ]
}

// SwiftUI view extensions for consistent theming
public extension View {
    func BookStrideBackground() -> some View {
        self.modifier(BookStrideBackgroundModifier())
    }
    
    func BookStrideCardStyle(cornerRadius: CGFloat = 14) -> some View {
        self.modifier(BookStrideCardModifier(cornerRadius: cornerRadius))
    }
}

public struct BookStrideBackgroundModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(BookStrideTheme.warmIvory.ignoresSafeArea())
    }
}

public struct BookStrideCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BookStrideTheme.cardLight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(BookStrideTheme.borderLight, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04), radius: 6, x: 0, y: 2)
    }
}

extension Color {
    public init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 45, 90, 67)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
