//
//  NotificationService.swift
//  BookStride
//
//  Notification scheduling for daily reading habits with strict opt-in consent.
//

import Foundation
import UserNotifications

public final class NotificationService: ObservableObject {
    public static let shared = NotificationService()
    public static let reminderIdentifier = "bookstride.daily.reading.reminder"
    
    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    public init() {
        Task {
            await checkStatus()
        }
    }
    
    @MainActor
    public func checkStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
    }
    
    @MainActor
    public func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await checkStatus()
            return granted
        } catch {
            await checkStatus()
            return false
        }
    }
    
    public func scheduleDailyReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Time for your reading ritual"
        content.body = "A few quiet pages with Bookstride keep your streak flowing."
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: Self.reminderIdentifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule reading reminder: \(error.localizedDescription)")
            }
        }
    }
    
    public func cancelDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }
}

