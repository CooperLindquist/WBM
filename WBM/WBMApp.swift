//
//  WBMApp.swift
//  WBM
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleMobileAds
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["6ce3cb3e6c9dfdf63940ebc12abb9ea5"]
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationManager.shared.cancelEngagementReminder()

        // Update lastActive so this user scores higher in others' swipe feeds
        if let uid = Auth.auth().currentUser?.uid {
            Firestore.firestore().collection("users").document(uid)
                .updateData(["lastActive": Timestamp(date: Date())])
        }

        // Re-verify subscription status every time the app comes to foreground
        // (catches renewals, cancellations, and billing-issue resolutions)
        Task { await SubscriptionManager.shared.refresh() }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        NotificationManager.shared.scheduleEngagementReminder()
    }
}

@main
struct WBMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if sessionManager.isLoading {
                    LoadingView()
                } else if !sessionManager.isSignedIn {
                    Start()
                } else if sessionManager.isSignedIn && !sessionManager.hasCompletedProfile {
                    EditProfileView(mode: .initialSetup, onSave: nil)
                } else {
                    TabBarView()
                }
            }
            .environmentObject(sessionManager)
            .environmentObject(subscriptionManager)
            .animation(.default, value: sessionManager.isSignedIn)
            .animation(.default, value: sessionManager.isLoading)
            .task {
                // Refresh subscription on cold launch (after sign-in state settles)
                if Auth.auth().currentUser != nil {
                    await SubscriptionManager.shared.refresh()
                }
            }
        }
    }
}
