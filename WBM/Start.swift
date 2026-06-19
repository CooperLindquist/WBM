import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseAuth

struct Start: View {
    @State private var navigationState: NavigationState = .none  // Navigation state
    @Environment(\.colorScheme) var colorScheme

    enum NavigationState {
        case none
        case onboarding
        case tabBar
    }

    var body: some View {
        Group {
            switch navigationState {
            case .tabBar:
                TabBarView()  // Navigate to TabBarView
            case .onboarding:
                OnboardingView()  // Navigate to OnboardingView
            case .none:
                ZStack {
                    // Gradient background
                    LinearGradient(
                        gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.blue.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
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
                
                guard let uid = authResult?.user.uid else { return }
                checkOnboardingStatus(for: uid)
            }
        }
    }
    
    private func checkOnboardingStatus(for userId: String) {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(userId)
        
        userDoc.getDocument { document, error in
            if let document = document, document.exists {
                let isOnboarded = document.get("isOnboarded") as? Bool ?? false
                navigationState = isOnboarded ? .tabBar : .onboarding
            } else {
                // Document doesn't exist; assume new user
                navigationState = .onboarding
                userDoc.setData([
                    "isOnboarded": false,
                    "premium": false  // New field added with default value
                ], merge: true)
            }
        }
    }

}

#Preview {
    Start()
}
