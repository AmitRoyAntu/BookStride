//
//  AppleBooksService.swift
//  BookStride
//
//  Clean integration with Apple Books via public URL schemes.
//

import UIKit

public enum AppleBooksService {
    /// Attempts to open the Apple Books application.
    @MainActor
    public static func openAppleBooks() {
        // Primary URL scheme for Apple Books on iPadOS
        if let url = URL(string: "ibooks://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        
        // Fallback iTunes books scheme
        if let url = URL(string: "itms-books://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        
        // If neither is directly openable, try standard scheme
        if let url = URL(string: "ibooks://") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

