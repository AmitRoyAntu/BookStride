//
//  ColorTheme.swift
//  BookStride
//
//  Adaptive design system for the BookStride reading journal aesthetic.
//  Fully supports Light and Dark modes with high-contrast, comfortable typography.
//

import SwiftUI
import UIKit

public enum BookStrideTheme {
    // Dynamic Primary Text: deep charcoal in light mode, crisp warm cream-white in dark mode
    public static let deepCharcoal = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 245/255, green: 243/255, blue: 238/255, alpha: 1.0)
            : UIColor(red: 35/255, green: 33/255, blue: 30/255, alpha: 1.0)
    })
    
    // Dynamic Secondary Text: muted slate in light mode, soft readable warm gray in dark mode
    public static let mutedSlate = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 185/255, green: 180/255, blue: 172/255, alpha: 1.0)
            : UIColor(red: 110/255, green: 106/255, blue: 98/255, alpha: 1.0)
    })
    
    // Dynamic Card Surface: pure white in light mode, warm charcoal surface in dark mode
    public static let cardLight = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 38/255, green: 36/255, blue: 33/255, alpha: 1.0)
            : UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 1.0)
    })
    public static let cardDark = Color(red: 38/255, green: 36/255, blue: 33/255)
    
    // Dynamic Card Border: soft warm sand in light mode, subtle dark border in dark mode
    public static let borderLight = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 58/255, green: 55/255, blue: 50/255, alpha: 1.0)
            : UIColor(red: 232/255, green: 228/255, blue: 220/255, alpha: 1.0)
    })
    public static let borderDark = Color(red: 58/255, green: 55/255, blue: 50/255)
    
    // Dynamic Background: warm ivory in light mode, deep obsidian/charcoal in dark mode
    public static let warmIvory = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 24/255, green: 23/255, blue: 21/255, alpha: 1.0)
            : UIColor(red: 249/255, green: 248/255, blue: 245/255, alpha: 1.0)
    })
    public static let darkCharcoal = Color(red: 24/255, green: 23/255, blue: 21/255)
    
    // Dynamic Accent: muted forest green in light mode, vibrant sage/forest green in dark mode
    public static let forestGreen = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 88/255, green: 158/255, blue: 118/255, alpha: 1.0)
            : UIColor(red: 45/255, green: 90/255, blue: 67/255, alpha: 1.0)
    })
    
    public static let forestGreenLight = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 115/255, green: 185/255, blue: 145/255, alpha: 1.0)
            : UIColor(red: 75/255, green: 130/255, blue: 100/255, alpha: 1.0)
    })
    
    // Secondary accent: warm beige / sand
    public static let warmBeige = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 75/255, green: 70/255, blue: 62/255, alpha: 1.0)
            : UIColor(red: 216/255, green: 206/255, blue: 191/255, alpha: 1.0)
    })
    public static let sandDark = Color(red: 70/255, green: 65/255, blue: 57/255)
    
    // High-contrast text helpers
    public static let lightText = Color(red: 245/255, green: 243/255, blue: 238/255)
    public static let lightMutedText = Color(red: 185/255, green: 180/255, blue: 172/255)
    
    // Streak amber
    public static let streakAmber = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 240/255, green: 155/255, blue: 65/255, alpha: 1.0)
            : UIColor(red: 217/255, green: 130/255, blue: 43/255, alpha: 1.0)
    })
    
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
