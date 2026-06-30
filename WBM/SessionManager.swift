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
    @Published var isSignedIn = false
    @Published var hasCompletedProfile = false
    @Published var isLoading = true
    private var authHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }

            self.isLoading = true

            guard let user = user else {
                DispatchQueue.main.async {
                    self.isSignedIn = false
                    self.hasCompletedProfile = false
                    self.isLoading = false
                }
                return
            }

            self.checkUserDocument(uid: user.uid)
        }
    }

    
    private func checkUserDocument(uid: String) {
        let userRef = Firestore.firestore().collection("users").document(uid)

        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    self.hasCompletedProfile = data["hasCompletedProfile"] as? Bool ?? false
                    self.isSignedIn = true
                } else {
                    self.createNewUserDocument(ref: userRef)
                }

                self.isLoading = false
            }
        }
    }

    
    private func createNewUserDocument(ref: DocumentReference) {
        ref.setData([
            "spotlightsRemaining": 1,
            "diamonds": 100,
            "name": "",
            "bio": "",
            "height": "66",
            "weight": "150",
            "gender": "",
            "relationshipGoal": "",
            "languages": [],
            "profileImageURLs": [],
            "hasCompletedProfile": false
        ])
 { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error creating user document: \(error.localizedDescription)")
                self.isSignedIn = true
                self.hasCompletedProfile = false
            } else {
                print("User document created successfully.")
                self.isSignedIn = true
                self.hasCompletedProfile = false

            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            // Auth listener will automatically update isSignedIn state
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    /// Permanently deletes the signed-in user's Firestore data and Firebase Auth account.
    /// If Firebase requires a recent sign-in to perform this sensitive action, the
    /// `.requiresRecentLogin` case is returned so the UI can prompt the user to sign in again.
    enum DeleteAccountError: Error {
        case noUser
        case requiresRecentLogin
        case other(Error)
    }

    func deleteAccount(completion: @escaping (DeleteAccountError?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.noUser)
            return
        }

        let uid = user.uid
        let userRef = Firestore.firestore().collection("users").document(uid)

        // Delete the Firestore profile document first, then delete the Auth account.
        userRef.delete { [weak self] error in
            if let error = error {
                print("Error deleting user document: \(error.localizedDescription)")
                // Continue on to try deleting the auth account anyway.
            }

            user.delete { error in
                guard let self = self else { return }

                if let error = error as NSError? {
                    if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        completion(.requiresRecentLogin)
                    } else {
                        print("Error deleting account: \(error.localizedDescription)")
                        completion(.other(error))
                    }
                    return
                }

                // Auth listener will automatically flip isSignedIn to false,
                // but we set it explicitly too for an immediate UI update.
                DispatchQueue.main.async {
                    self.isSignedIn = false
                    self.hasCompletedProfile = false
                }
                completion(nil)
            }
        }
    }
    
    deinit {
        if let handle = authHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
