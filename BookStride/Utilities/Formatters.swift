//
//  Formatters.swift
//  BookStride
//
//  Text and time formatting utilities for BookStride.
//

import Foundation

public enum DurationStyle {
    case full     // "1 hour 25 mins", "42 mins", "45 secs"
    case short    // "1h 25m", "42m", "45s"
    case timer    // "01:25:40" (HH:MM:SS) or "25:40" (MM:SS)
    case compact  // "1.4 hrs" or "42 min"
}

public enum DateStyleType {
    case fullDate     // "October 29, 2026"
    case mediumDate   // "Oct 29, 2026"
    case shortDate    // "10/29/26"
    case relative     // "Today", "Yesterday", "3 days ago"
    case timeOnly     // "3:45 PM"
    case dateTime     // "Oct 29 at 3:45 PM"
}

public enum Formatters {
    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()
    
    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
    
    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
    
    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d 'at' h:mm a"
        return f
    }()
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
    
    public static func preferredDurationStyle() -> DurationStyle {
        let raw = UserDefaults.standard.string(forKey: "bookstride_preferred_duration_style") ??
                  UserDefaults.standard.string(forKey: "BookStride_preferred_duration_style") ??
                  UserDefaults.standard.string(forKey: "readflow_preferred_duration_style") ?? "full"
        switch raw {
        case "short": return .short
        case "compact": return .compact
        default: return .full
        }
    }
    
    /// Formats seconds into a human-readable duration string.
    public static func formatDuration(seconds: Int, style: DurationStyle = .full) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let remainingSeconds = safeSeconds % 60
        
        switch style {
        case .timer:
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
            } else {
                return String(format: "%02d:%02d", minutes, remainingSeconds)
            }
            
        case .short:
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else if minutes > 0 {
                return "\(minutes)m"
            } else {
                return "\(remainingSeconds)s"
            }
            
        case .full:
            if hours > 0 {
                let hourWord = hours == 1 ? "hr" : "hrs"
                let minWord = minutes == 1 ? "min" : "mins"
                if minutes > 0 {
                    return "\(hours) \(hourWord) \(minutes) \(minWord)"
                } else {
                    return "\(hours) \(hourWord)"
                }
            } else if minutes > 0 {
                let minWord = minutes == 1 ? "minute" : "minutes"
                return "\(minutes) \(minWord)"
            } else if safeSeconds > 0 {
                return "\(remainingSeconds) sec"
            } else {
                return "0 min"
            }
            
        case .compact:
            if hours > 0 {
                let decimal = Double(safeSeconds) / 3600.0
                return String(format: "%.1f hrs", decimal)
            } else {
                return "\(minutes) min"
            }
        }
    }
    
    /// Formats a Date according to style.
    public static func formatDate(_ date: Date, style: DateStyleType = .mediumDate) -> String {
        switch style {
        case .fullDate:
            return fullDateFormatter.string(from: date)
        case .mediumDate:
            return mediumDateFormatter.string(from: date)
        case .shortDate:
            return shortDateFormatter.string(from: date)
        case .timeOnly:
            return timeOnlyFormatter.string(from: date)
        case .dateTime:
            return dateTimeFormatter.string(from: date)
        case .relative:
            let cal = Calendar.current
            if cal.isDateInToday(date) {
                return "Today"
            } else if cal.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
            }
        }
    }
    
    /// Formats page progress into a readable string.
    public static func formatPages(current: Int?, total: Int?) -> String {
        switch (current, total) {
        case let (.some(curr), .some(tot)) where tot > 0:
            return "Page \(curr) of \(tot)"
        case let (.some(curr), _):
            return "Page \(curr)"
        case let (_, .some(tot)) where tot > 0:
            return "\(tot) pages"
        default:
            return "Pages unrecorded"
        }
    }
    
    /// Formats a 0.0 - 1.0 progress fraction into percentage string.
    public static func formatPercentage(_ progress: Double) -> String {
        let clamped = max(0.0, min(1.0, progress))
        let percentage = Int(round(clamped * 100))
        return "\(percentage)%"
    }
}

