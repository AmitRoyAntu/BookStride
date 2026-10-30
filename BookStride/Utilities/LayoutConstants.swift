//
//  LayoutConstants.swift
//  BookStride
//
//  Responsive layout constants for iPad and adaptive split view presentation.
//

import SwiftUI

public enum LayoutConstants {
    public static let cardCornerRadius: CGFloat = 16
    public static let smallCornerRadius: CGFloat = 10
    public static let pillCornerRadius: CGFloat = 20
    
    public static let standardPadding: CGFloat = 20
    public static let cardInnerPadding: CGFloat = 18
    public static let compactPadding: CGFloat = 12
    
    // Book cover aspect ratio (approx 2:3)
    public static let bookCoverAspectRatio: CGFloat = 2.0 / 3.0
    public static let bookGridCardWidth: CGFloat = 170
    public static let bookGridCardHeight: CGFloat = 255
    public static let bookDetailCoverWidth: CGFloat = 220
    public static let bookDetailCoverHeight: CGFloat = 330
    
    // Grid columns for iPad library
    public static let libraryColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 24)
    ]
    
    // Grid columns for dashboard widgets
    public static let dashboardColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 320, maximum: 500), spacing: 20)
    ]
}

// MARK: - Multiplatform SwiftUI Compatibility

#if os(macOS)
public enum NavigationBarTitleDisplayModeCompat {
    case automatic
    case inline
    case large
}

public enum UIKeyboardTypeCompat {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad
}

public enum TextInputAutocapitalizationCompat {
    case never
    case words
    case sentences
    case characters
}

extension View {
    @ViewBuilder
    public func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayModeCompat) -> some View {
        self
    }
    
    @ViewBuilder
    public func keyboardType(_ type: UIKeyboardTypeCompat) -> some View {
        self
    }
    
    @ViewBuilder
    public func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalizationCompat?) -> some View {
        self
    }
}
#endif
