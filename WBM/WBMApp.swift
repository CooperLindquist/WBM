//
//  WBMApp.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds // Import Google Mobile Ads SDK

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Google Mobile Ads SDK
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
        // Set test device identifiers
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = ["6ce3cb3e6c9dfdf63940ebc12abb9ea5"]
        
        return true
    }
}

@main
struct WBMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var sessionManager = SessionManager()
    
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
            .animation(.default, value: sessionManager.isSignedIn)
            .animation(.default, value: sessionManager.isLoading)
        }
    }
}
