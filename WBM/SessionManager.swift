//
//  SessionManager.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI
import Combine
import FirebaseAuth
import Firebase

class SessionManager: ObservableObject {
    @Published var isSignedIn: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }
    @Published var isFirstTimeUser: Bool = false {
        didSet {
            objectWillChange.send()
        }
    }
    @Published var isLoading: Bool = true // Add loading state

    func checkAuthState() {
        isLoading = true // Set loading to true while checking authentication state
        if let user = Auth.auth().currentUser {
            // Check if the user exists in the Firestore database
            let userRef = Firestore.firestore().collection("users").document(user.uid)
            userRef.getDocument { document, error in
                if let document = document, document.exists {
                    self.isFirstTimeUser = false
                    self.isSignedIn = true
                } else {
                    self.isFirstTimeUser = true
                }
                self.isLoading = false // Stop loading after the check
            }
        } else {
            isSignedIn = false
            isLoading = false // Stop loading if no user is signed in
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
        } catch let error as NSError {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}
