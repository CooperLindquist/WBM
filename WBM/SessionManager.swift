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
        isLoading = true // Start loading
        if let user = Auth.auth().currentUser {
            let userRef = Firestore.firestore().collection("users").document(user.uid)
            userRef.getDocument { document, error in
                if let error = error {
                    print("Error fetching user document: \(error.localizedDescription)")
                    self.isSignedIn = false
                    self.isFirstTimeUser = false
                    self.isLoading = false
                    return
                }

                if let document = document, document.exists {
                    print("Existing user found.")
                    self.isFirstTimeUser = false
                    self.isSignedIn = true
                    self.isLoading = false // End loading
                } else {
                    print("First-time user detected. Creating document...")
                    // Create user document
                    userRef.setData([
                        "spotlightsRemaining": 1,
                        "diamonds": 100,
                        "name": "",
                        "bio": "",
                        "height": "66",
                        "weight": "150",
                        "gender": "",
                        "relationshipGoal": "",
                        "languages": [],
                        "profileImageURLs": []
                    ]) { error in
                        if let error = error {
                            print("Error creating user document: \(error.localizedDescription)")
                            self.isFirstTimeUser = false
                        } else {
                            print("User document created successfully.")
                            self.isFirstTimeUser = true
                        }
                        self.isSignedIn = true
                        self.isLoading = false // End loading after document creation
                    }
                }
            }
        } else {
            print("No user signed in.")
            isSignedIn = false
            isFirstTimeUser = false
            isLoading = false
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
