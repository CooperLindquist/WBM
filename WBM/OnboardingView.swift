import SwiftUI
import Firebase
import PhotosUI
import FirebaseAuth
import Cloudinary


struct OnboardingView: View {
    @StateObject private var photoManager = PhotoUploadManager()
    @State private var navigateToTabBarView: Bool = false
    @State private var profileDataUpdated: Bool = false
    @State private var profileImageURLs: [String] = []
    @State var initialProfileData: [String: Any] = [:]
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var height: Int = 66
    @State private var weight: Double = 150
    @State private var gender: String = ""
    @State private var relationshipGoal: String = ""
    @State private var selectedLanguages: [String] = []
    @State private var isShowingLanguageList = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let maxPhotos = 6
    private let minPhotos = 3
    private let relationshipGoals = ["Short-term", "Long-term", "Friends", "Marriage"]

    private var uploadedPhotoCount: Int {
        photoManager.photos.filter { $0.remoteURL != nil }.count
    }

    private var missingFields: [String] {
        var missing: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Name") }
        if bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.append("Bio") }
        if gender.isEmpty { missing.append("Gender") }
        if relationshipGoal.isEmpty { missing.append("Relationship Goal") }
        if selectedLanguages.isEmpty { missing.append("Languages") }
        if uploadedPhotoCount < minPhotos { missing.append("at least \(minPhotos) photos (\(uploadedPhotoCount)/\(minPhotos) uploaded)") }
        return missing
    }

    private var isFormValid: Bool {
        missingFields.isEmpty
    }
    
    var body: some View {
        ZStack {
                if navigateToTabBarView {
                    TabBarView()
                } else {
                    onboardingContent
                }
            }
            .alert("Upload Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .animation(.easeInOut, value: navigateToTabBarView)
        }
    
    private var onboardingContent: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        HeaderView
                        
                        PersonalInfoSection
                        PhysicalAttributesSection
                        GenderSection
                        RelationshipGoalSection
                        LanguageSelectionSection
                        ProfilePicturesSection
                        
                        if !isFormValid {
                            Text("Please complete: \(missingFields.joined(separator: ", "))")
                                .font(.footnote)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        SaveButton
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: loadInitialData)
        .sheet(isPresented: $isShowingLanguageList) {
            LanguageList(selectedLanguages: $selectedLanguages)
        }
    }
    
    
    private var HeaderView: some View {
        VStack {
            Text("Welcome!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Complete your profile to get started.")
                .foregroundColor(.white)
                .font(.subheadline)
        }
        .padding(.top, 40)
    }
    
    private var PersonalInfoSection: some View {
        SectionView(title: "Personal Info") {
            VStack(spacing: 15) {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Bio", text: $bio)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var PhysicalAttributesSection: some View {
        SectionView(title: "Physical Attributes") {
            VStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Height: \(height / 12)'\(height % 12)\"")
                    Slider(value: Binding(
                        get: { Double(height) },
                        set: { height = Int($0) }
                    ), in: 36...96, step: 1)
                }
                
                VStack(alignment: .leading) {
                    Text("Weight: \(Int(weight)) lbs")
                    Slider(value: $weight, in: 50...400, step: 1)
                }
            }
        }
    }
    
    private var GenderSection: some View {
        SectionView(title: "Gender") {
            Picker("Gender", selection: $gender) {
                Text("Male").tag("Male")
                Text("Female").tag("Female")
                Text("Other").tag("Other")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var RelationshipGoalSection: some View {
        SectionView(title: "Relationship Goal") {
            VStack(alignment: .leading, spacing: 15) {
                ForEach(relationshipGoals, id: \.self) { goal in
                    HStack {
                        Text(goal)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(relationshipGoal == goal ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .onTapGesture {
                                relationshipGoal = goal
                            }
                    }
                }
            }
        }
    }
    
    
    private var LanguageSelectionSection: some View {
        SectionView(title: "Languages") {
            Button("Select Languages") {
                isShowingLanguageList = true
            }
            .buttonStyle(FilledButtonStyle())
        }
    }
    
    private var ProfilePicturesSection: some View {
        SectionView(title: "Profile Pictures") {
            PhotoGridEditor(manager: photoManager, maxPhotos: maxPhotos)
        }
    }
    
    
    private var SaveButton: some View {
        Button(action: saveProfileData) {
            Text("Save")
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(photoManager.isUploadingAny || !isFormValid ? Color.gray : Color.blue)
                .cornerRadius(10)
        }
        .disabled(photoManager.isUploadingAny || !isFormValid) // Disable if uploading or form incomplete
    }
    
    
    
    
    private func SectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            content()
                .padding()
                .background(Color.white.opacity(0.8))
                .cornerRadius(15)
        }
    }
    
    private func loadInitialData() {
        guard let user = Auth.auth().currentUser else { return }

        Firestore.firestore().collection("users").document(user.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching initial data: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                let data = document.data() ?? [:]
                name = data["name"] as? String ?? ""
                bio = data["bio"] as? String ?? ""
                height = Int(data["height"] as? String ?? "66") ?? 66
                weight = Double(data["weight"] as? String ?? "150") ?? 150
                gender = data["gender"] as? String ?? ""
                relationshipGoal = data["relationshipGoal"] as? String ?? ""
                selectedLanguages = data["languages"] as? [String] ?? []

                if let imageURLs = data["profileImageURLs"] as? [String] {
                    photoManager.loadExisting(urls: imageURLs)
                }
            }
        }
    }

    private func saveProfileData() {
        guard let user = Auth.auth().currentUser else { return }

        guard isFormValid else {
            errorMessage = "Please complete the following before continuing: \(missingFields.joined(separator: ", "))."
            showErrorAlert = true
            return
        }

        let updatedData: [String: Any] = [
            "name": name,
            "bio": bio,
            "height": "\(height)",
            "weight": "\(Int(weight))",
            "gender": gender,
            "relationshipGoal": relationshipGoal,
            "languages": selectedLanguages
        ]
        
        Firestore.firestore().collection("users").document(user.uid).setData(updatedData, merge: true) { error in
            if let error = error {
                print("Error saving profile data: \(error.localizedDescription)")
            } else {
                print("Successfully saved profile data.")
                completeOnboarding(for: user.uid)
            }
        }
    }
    
    private func completeOnboarding(for userId: String) {
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(userId)
        
        userDoc.updateData(["isOnboarded": true]) { error in
            if let error = error {
                print("Error updating onboarding status: \(error.localizedDescription)")
            } else {
                print("Onboarding completed for user \(userId).")
                navigateToTabBarView = true // Trigger navigation
            }
        }
    }
}


// Image cropping, orientation-fixing, and HEIC conversion now live as
// shared helpers in PhotoUploadManager.swift — removed the dead duplicates
// that were here.

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView()
}
