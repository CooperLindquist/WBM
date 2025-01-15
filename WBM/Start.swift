//
//  Start.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseAuth

struct Start: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Group {
            if sessionManager.isLoading {
                LoadingView()  // Show loading view while checking auth state
            } else if sessionManager.isSignedIn {
                if sessionManager.isFirstTimeUser {
                    OnboardingView()
                } else {
                    TabBarView()
                }
            } else {
                ZStack {
                    // Gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.blue.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.all)

                    VStack(spacing: 20) {
                        // WBM Logo
                        Image("WBM_resized")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .shadow(radius: 10)

                        Text("Welcome to WBM")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                            .padding(.top, 20)

                        Spacer()

                        // Google Sign-In Button
                        Button(action: {
                            signInWithGoogle()
                        }) {
                            HStack {
                                Image("Google")
                                    .resizable()
                                    .frame(width: 25, height: 25)
                                Text("Sign in with Google")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        }
                        .padding(.horizontal, 40)

                        Spacer()

                        Text("Weight-Based Matchmaking")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 20)
                    }
                    .padding(.top, 40)
                }
            }
        }
        .onAppear {
            checkAuthState()
        }
    }

    private func checkAuthState() {
        sessionManager.isLoading = true  // Show loading state
        if let user = Auth.auth().currentUser {
            let userRef = Firestore.firestore().collection("users").document(user.uid)
            userRef.getDocument { document, error in
                if let document = document, document.exists {
                    sessionManager.isFirstTimeUser = false
                    sessionManager.isSignedIn = true
                } else {
                    sessionManager.isFirstTimeUser = true
                    sessionManager.isSignedIn = true  // Still signed in, but first time user
                }
                sessionManager.isLoading = false  // Stop loading after the check
            }
        } else {
            sessionManager.isSignedIn = false
            sessionManager.isLoading = false  // Stop loading if no user is signed in
        }
    }

    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        return windowScene.windows.first?.rootViewController
    }

    private func signInWithGoogle() {
        guard let rootViewController = getRootViewController() else {
            print("Unable to access root view controller")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }

            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Error retrieving Google Sign-In user data")
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                            accessToken: user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Sign-In error: \(error.localizedDescription)")
                    return
                }

                print("User signed in: \(authResult?.user.displayName ?? "Unknown")")
                sessionManager.isSignedIn = true
            }
        }
    }
}


#Preview {
    Start()
        .environmentObject(SessionManager())
}
