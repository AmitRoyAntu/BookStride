//
//  AppleBooksService.swift
//  BookStride
//
//  Clean integration with Apple Books via public URL schemes and Store URLs.
//  Uses documented iPadOS APIs without accessing Apple Books' private storage or reading state.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum AppleBooksService {
    
    // MARK: - URL Validation
    
    /// Checks whether a given string is a valid, supported Apple Books link.
    /// Supports `ibooks://`, `itms-books://`, and standard web links `https://books.apple.com/*`.
    public static func isValidAppleBooksURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return false
        }
        
        if scheme == "ibooks" || scheme == "itms-books" {
            return true
        }
        
        if (scheme == "https" || scheme == "http"), let host = url.host?.lowercased() {
            return host == "books.apple.com" || host.hasSuffix(".books.apple.com")
        }
        
        return false
    }
    
    /// Generates a documented Apple Books store search URL for a given title and optional author.
    public static func searchStoreURL(title: String, author: String = "") -> URL? {
        var query = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query += " \(author)"
        }
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "https://books.apple.com/us/search?term=\(encoded)")
    }
    
    // MARK: - Open Actions
    
    /// Attempts to open a specific book in Apple Books if a valid link exists,
    /// optionally falling back to opening the Apple Books app.
    @MainActor
    @discardableResult
    public static func openBook(
        urlString: String?,
        fallbackToApp: Bool = true,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool {
        if let link = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !link.isEmpty,
           let url = URL(string: link),
           isValidAppleBooksURL(link) {
            
            #if canImport(UIKit)
            UIApplication.shared.open(url, options: [:]) { success in
                if !success && fallbackToApp {
                    openAppleBooks(completion: completion)
                } else {
                    completion?(success)
                }
            }
            #elseif canImport(AppKit)
            let success = NSWorkspace.shared.open(url)
            if !success && fallbackToApp {
                openAppleBooks(completion: completion)
            } else {
                completion?(success)
            }
            #endif
            return true
        }
        
        if fallbackToApp {
            openAppleBooks(completion: completion)
            return true
        }
        
        completion?(false)
        return false
    }
    
    /// Opens the Apple Books application via documented URL schemes.
    @MainActor
    public static func openAppleBooks(completion: ((Bool) -> Void)? = nil) {
        #if canImport(UIKit)
        // Primary URL scheme for Apple Books on iPadOS
        if let url = URL(string: "ibooks://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
            return
        }
        
        // Fallback iTunes books scheme
        if let url = URL(string: "itms-books://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
            return
        }
        
        // If neither is directly openable, try standard scheme
        if let url = URL(string: "ibooks://") {
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
            return
        }
        #elseif canImport(AppKit)
        if let url = URL(string: "ibooks://") {
            let success = NSWorkspace.shared.open(url)
            completion?(success)
            return
        }
        #endif
        
        completion?(false)
    }
}
