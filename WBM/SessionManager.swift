//
//  SessionManager.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI
import Combine
import FirebaseAuth

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
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            isSignedIn = false
        } catch let error as NSError {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

