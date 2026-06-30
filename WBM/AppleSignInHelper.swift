//
//  AppleSignInHelper.swift
//  WBM
//
//  Bridges SwiftUI's SignInWithAppleButton to Firebase Auth, mirroring the
//  existing Google sign-in flow in Start.swift.
//

import AuthenticationServices
import CryptoKit
import FirebaseAuth

final class AppleSignInHelper {
    private var currentNonce: String?

    /// Call from `SignInWithAppleButton`'s `onRequest` closure. Generates and stores a
    /// nonce, and returns its SHA256 hash to set on the `ASAuthorizationAppleIDRequest`.
    func prepareRequest() -> String {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        return Self.sha256(nonce)
    }

    /// Call from `SignInWithAppleButton`'s `onCompletion` closure. Exchanges the Apple
    /// credential for a Firebase credential and signs the user in.
    /// `onSignedIn` is called on success with the resulting Firebase uid.
    func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>, onSignedIn: @escaping (String) -> Void) {
        switch result {
        case .failure(let error):
            // ASAuthorizationError.canceled fires when the user dismisses the sheet; no need to log that as a hard error.
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                print("Apple Sign-In error: \(error.localizedDescription)")
            }

        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                print("Apple Sign-In error: unexpected credential type")
                return
            }

            guard let nonce = currentNonce else {
                print("Apple Sign-In error: missing nonce")
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Apple Sign-In error: unable to fetch identity token")
                return
            }

            let credential = OAuthProvider.credential(providerID: .apple,
                                                       idToken: idTokenString,
                                                       rawNonce: nonce)

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Sign-In error: \(error.localizedDescription)")
                    return
                }

                guard let user = authResult?.user else { return }

                // Apple only provides the user's name on the very first sign-in.
                // Save it as the Firebase displayName if we don't already have one.
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")
                    if !displayName.isEmpty, user.displayName == nil {
                        let changeRequest = user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        changeRequest.commitChanges(completion: nil)
                    }
                }

                onSignedIn(user.uid)
            }
        }
    }

    // MARK: - Nonce helpers

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}
