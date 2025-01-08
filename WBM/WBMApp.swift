//
//  WBMApp.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct WBMApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                if sessionManager.isLoading {
                    LoadingView()
                } else if sessionManager.isSignedIn {
                    TabBarView()
                        .environmentObject(sessionManager)
                } else {
                    Start()
                        .environmentObject(sessionManager)
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .onAppear {
                sessionManager.checkAuthState()
            }
        }
    }
}
