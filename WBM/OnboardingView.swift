import SwiftUI
import Firebase
import PhotosUI
import FirebaseAuth
import Cloudinary

struct OnboardingView: View {
    @State private var profileDataUpdated: Bool = false
    @State private var uploadingImageIndices: Set<Int> = []
    @State private var uploadsInProgress: Int = 0
    @State private var isUploadingImages: Bool = false
    @State private var profileImageURLs: [String] = []
    @State var initialProfileData: [String: Any] = [:]
    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var height: Int = 66
    @State private var weight: Double = 150
    @State private var gender: String = ""
    @State private var relationshipGoal: String = ""
    @State private var selectedLanguages: [String] = []
    @State private var selectedImages: [UIImage] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isShowingLanguageList = false
    @Environment(\.dismiss) var dismiss

    private let relationshipGoals = ["Short-term", "Long-term", "Friends", "Marriage"]
    private let cloudinary = CLDCloudinary(configuration: CLDConfiguration(cloudName: "dfxodj9gk", apiKey: "998259646284382"))

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(spacing: 30) {
                    HeaderView

                    PersonalInfoSection
                    PhysicalAttributesSection
                    GenderSection
                    RelationshipGoalSection
                    LanguageSelectionSection
                    ProfilePicturesSection

                    SaveButton
                }
                .padding()
            }
        }
        .onAppear(perform: loadInitialData)
        .onChange(of: photoItems) { _, newItems in
            loadImages(from: newItems)
        }
        .sheet(isPresented: $isShowingLanguageList) {
            // Assuming LanguageList is defined elsewhere
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
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(selectedImages.indices, id: \.self) { index in
                            VStack {
                                ZStack {
                                    // Image
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    // Loading indicator if the image is still uploading
                                    if uploadingImageIndices.contains(index) {
                                        Color.black.opacity(0.5)
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(2)
                                    }
                                }

                                // Trash button
                                Button(action: {
                                    removeProfilePicture(at: index)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: 6 - selectedImages.count,
                            matching: .images,
                            label: {
                                Image(systemName: "plus")
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .clipShape(Circle())
                            }
                        )
                    }
                }
            }
        }
    }


    private var SaveButton: some View {
        Button(action: saveProfileData) {
            Text("Save")
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isUploadingImages ? Color.gray : Color.blue)
                .cornerRadius(10)
        }
        .disabled(isUploadingImages)  // Disable if images are still uploading
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

    private func removeProfilePicture(at index: Int) {
        guard index < selectedImages.count, index < profileImageURLs.count else { return }

        let removedImage = selectedImages.remove(at: index)
        let imageUrl = profileImageURLs.remove(at: index) // Remove URL from the array

        removeImageUrlFromFirestore(imageUrl: imageUrl) // Remove from Firestore
    }



    private func removeImageUrlFromFirestore(imageUrl: String) {
        guard let user = Auth.auth().currentUser else {
            print("No authenticated user found")
            return
        }
        let userDoc = Firestore.firestore().collection("users").document(user.uid)
        
        // Fetch the document to check if 'profileImageURLs' exists and is an array
        userDoc.getDocument { document, error in
            if let error = error {
                print("❌ Error fetching document: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Document does not exist")
                return
            }

            // Confirm the profileImageURLs field exists and is an array
            if let imageUrls = document.data()?["profileImageURLs"] as? [String] {
                print("Existing profileImageURLs: \(imageUrls)")

                // Proceed to remove the image URL from the array
                userDoc.updateData([
                    "profileImageURLs": FieldValue.arrayRemove([imageUrl])
                ]) { error in
                    if let error = error {
                        print("❌ Error removing image URL from Firestore: \(error.localizedDescription)")
                    } else {
                        print("✅ Successfully removed image URL from Firestore: \(imageUrl)")
                    }
                }
            } else {
                print("❌ profileImageURLs is not an array or doesn't exist")
            }
        }
    }

 
    
    private func loadImages(from items: [PhotosPickerItem]) {
        isUploadingImages = true
        uploadsInProgress = items.count

        for (index, item) in items.enumerated() {
            guard selectedImages.count < 6 else { return }

            uploadingImageIndices.insert(index) // Mark the image as uploading

            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let uiImage = UIImage(data: data) {
                        if let croppedImage = cropImageToVerticalRectangle(uiImage, aspectRatio: 3.0 / 4.0) {
                            selectedImages.append(croppedImage)
                            if let croppedData = croppedImage.jpegData(compressionQuality: 0.8) {
                                uploadImageToCloudinary(imageData: croppedData, atIndex: index)
                            }
                        }
                    }
                case .failure(let error):
                    print("Error loading image: \(error.localizedDescription)")
                }
            }
        }
    }

    private func uploadImageToCloudinary(imageData: Data, atIndex index: Int) {
        let params = CLDUploadRequestParams().setUploadPreset("profile pics")

        cloudinary.createUploader().upload(data: imageData, uploadPreset: "profile pics", params: params, completionHandler: { result, error in
            if let error = error {
                print("Error uploading to Cloudinary: \(error.localizedDescription)")
            } else if let result = result {
                if let secureUrl = result.secureUrl {
                    saveImageUrlToFirestore(url: secureUrl)
                }
            }

            // Decrement the number of uploads in progress
            uploadsInProgress -= 1
            uploadingImageIndices.remove(index) // Mark the image as uploaded

            // Once all uploads are complete, set isUploadingImages to false
            if uploadsInProgress == 0 {
                isUploadingImages = false
            }
        })
    }


    private func cropImageToVerticalRectangle(_ image: UIImage, aspectRatio: CGFloat = 3.0 / 4.0) -> UIImage? {
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        let originalAspectRatio = originalWidth / originalHeight

        var cropWidth = originalWidth
        var cropHeight = originalHeight

        if originalAspectRatio > aspectRatio {
            // Crop horizontally to match aspect ratio
            cropWidth = originalHeight * aspectRatio
        } else {
            // Crop vertically to match aspect ratio
            cropHeight = originalWidth / aspectRatio
        }

        let xOffset = (originalWidth - cropWidth) / 2
        let yOffset = (originalHeight - cropHeight) / 2
        let cropRect = CGRect(x: xOffset, y: yOffset, width: cropWidth, height: cropHeight)

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cropWidth, height: cropHeight))
        return renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: CGSize(width: cropWidth, height: cropHeight)))
        }
    }


    private func saveImageUrlToFirestore(url: String) {
        guard let user = Auth.auth().currentUser else { return }
        let userDoc = Firestore.firestore().collection("users").document(user.uid)

        userDoc.updateData([
            "profileImageURLs": FieldValue.arrayUnion([url])
        ]) { error in
            if let error = error {
                print("Error saving image URL to Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully added image URL to Firestore: \(url)")
            }
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
                    fetchImages(from: imageURLs)
                }
            }
        }
    }

    private func fetchImages(from imageURLs: [String]) {
        for urlString in imageURLs {
            if let url = URL(string: urlString) {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("Error fetching image: \(error.localizedDescription)")
                        return
                    }

                    if let data = data, let uiImage = UIImage(data: data) {
                        DispatchQueue.main.async {
                            selectedImages.append(uiImage)
                        }
                    }
                }.resume()
            }
        }
    }

    private func saveProfileData() {
        guard let user = Auth.auth().currentUser else { return }
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
                // Set the profile data updated flag to true
                profileDataUpdated = true
                loadInitialData() // Reload profile data
                dismiss() // Dismiss the onboarding view
            }
        }
    }


}
extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up {
            return self // No adjustment needed
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}


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
