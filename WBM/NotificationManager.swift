//
//  NotificationManager.swift
//  WBM
//
//  Handles local notifications (no Apple developer account needed).
//  These fire while the app is backgrounded but NOT when fully killed.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Notification permission granted: \(granted)")
        }
    }

    // MARK: - New Match

    func scheduleNewMatchNotification(matchName: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Match! 🎉"
        content.body = "You and \(matchName) matched. Say hello!"
        content.sound = .default

        // Fire after a short delay so it feels natural
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "match_\(matchName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - New Like

    func scheduleNewLikeNotification(count: Int) {
        // Debounce — cancel any pending like notification and replace with updated count
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pending_likes"])

        let content = UNMutableNotificationContent()
        content.title = count == 1 ? "Someone liked you! 💘" : "\(count) people liked you! 💘"
        content.body = "Open WBM to see who."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "pending_likes", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - New Message

    func scheduleNewMessageNotification(senderName: String, messagePreview: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(senderName) sent you a message 💬"
        content.body = messagePreview.count > 60
            ? String(messagePreview.prefix(60)) + "..."
            : messagePreview
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "message_\(senderName)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Spotlight Expiry Warning

    /// Call this when a user activates spotlight. Schedules a warning 1 hour before it expires.
    /// `spotlightDuration` is in seconds (default spotlight is 5 hours = 18000s)
    func scheduleSpotlightExpiryWarning(spotlightDuration: TimeInterval = 18000) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["spotlight_expiry"])

        let warningTime = spotlightDuration - 3600 // 1 hour before expiry
        guard warningTime > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your Spotlight is ending soon ⭐"
        content.body = "You have 1 hour left in the spotlight. Make it count!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: warningTime, repeats: false)
        let request = UNNotificationRequest(identifier: "spotlight_expiry", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Engagement Reminder

    /// Schedule a nudge if user hasn't opened the app. Call this on app background.
    /// Cancels itself if the user opens the app before it fires.
    func scheduleEngagementReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["engagement_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "You have people waiting 👀"
        content.body = "Check your likes and matches on WBM."
        content.sound = .default

        // Fire after 24 hours of inactivity
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)
        let request = UNNotificationRequest(identifier: "engagement_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Call this on app foreground to cancel the engagement reminder
    func cancelEngagementReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["engagement_reminder"])
    }

    // MARK: - Badge

    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }

    func setBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }
}
