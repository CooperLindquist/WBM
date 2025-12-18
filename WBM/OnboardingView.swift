import SwiftUI
import Firebase
import PhotosUI
import FirebaseAuth
import Cloudinary


struct OnboardingView: View {
    struct SelectedImage: Identifiable {
            let id = UUID()
            var image: UIImage
            var isUploading: Bool = false
            var imageUrl: String?
        }
    @State private var selectedImages: [SelectedImage] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var navigateToTabBarView: Bool = false
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
    @State private var isShowingLanguageList = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    private let relationshipGoals = ["Short-term", "Long-term", "Friends", "Marriage"]
    private let cloudinary = CLDCloudinary(configuration: CLDConfiguration(cloudName: "dfxodj9gk", apiKey: "998259646284382"))
    
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
        }
        .onAppear(perform: loadInitialData)
        .onChange(of: photoItems) { _, newItems in
            loadImages(from: newItems)
        }
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(selectedImages) { selectedImage in
                        VStack {
                            ZStack {
                                Image(uiImage: selectedImage.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                if selectedImage.isUploading {
                                    Color.black.opacity(0.5)
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                            }

                            Button {
                                if let index = selectedImages.firstIndex(where: { $0.id == selectedImage.id }) {
                                    removeProfilePicture(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    PhotosPicker(
                        selection: $photoItems,
                        maxSelectionCount: 6 - selectedImages.count,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .clipShape(Circle())
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
        .disabled(isUploadingImages) // Disable if images are still uploading
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
        guard index < selectedImages.count else { return }
        
        let removedImage = selectedImages.remove(at: index)
        if let imageUrl = removedImage.imageUrl {
            removeImageUrlFromFirestore(imageUrl: imageUrl)
        }
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
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showErrorAlert = true
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        isUploadingImages = true
        uploadsInProgress = items.count

        let newSelections = items.map { _ in
            SelectedImage(image: UIImage(), isUploading: true)
        }

        selectedImages.append(contentsOf: newSelections)

        for (index, item) in items.enumerated() {
            let imageID = newSelections[index].id
            loadSingleImage(item, imageID: imageID)
        }
    }
    private func loadSingleImage(_ item: PhotosPickerItem, imageID: UUID) {
        item.loadTransferable(type: Data.self) { result in
            switch result {
            case .success(let data):
                guard let data else {
                    self.failUpload(imageID)
                    return
                }

                DispatchQueue.global(qos: .userInitiated).async {
                    guard let uiImage = UIImage(data: data),
                          let jpegData = uiImage.normalizedImage().convertHEIFToJpeg()
                    else {
                        self.failUpload(imageID)
                        return
                    }

                    DispatchQueue.main.async {
                        self.updateImage(imageID, with: uiImage)
                        self.uploadImageToCloudinary(imageData: jpegData, for: imageID)
                    }
                }

            case .failure:
                self.failUpload(imageID)
            }
        }
    }
    private func updateImage(_ id: UUID, with image: UIImage) {
        guard let i = selectedImages.firstIndex(where: { $0.id == id }) else { return }
        selectedImages[i].image = image
    }
    private func failUpload(_ id: UUID) {
        DispatchQueue.main.async {
            selectedImages.removeAll { $0.id == id }
            uploadsInProgress -= 1
            if uploadsInProgress == 0 {
                isUploadingImages = false
            }
        }
    }

    
    private func uploadImageToCloudinary(imageData: Data, for imageId: UUID) {
        let params = CLDUploadRequestParams()
            .setUploadPreset("profile_pics")
            .setResourceType("image")
            
        
        // Validate image data first
        guard UIImage(data: imageData) != nil else {
            print("Invalid image data")
            DispatchQueue.main.async {
                guard let index = selectedImages.firstIndex(where: { $0.id == imageId }) else { return }
                selectedImages.remove(at: index)
            }
            return
        }
        
        cloudinary.createUploader().upload(
            data: imageData,
            uploadPreset: "profile_pics",
            params: params
        ) { result, error in
            DispatchQueue.main.async {
                guard let index = selectedImages.firstIndex(where: { $0.id == imageId }) else { return }
                
                if let error = error {
                    print("Cloudinary error details: \(error.userInfo)")
                    selectedImages.remove(at: index)
                    return
                }
                
                guard let secureUrl = result?.secureUrl else {
                    print("No URL returned from Cloudinary")
                    selectedImages.remove(at: index)
                    return
                }
                
                // Verify URL format
                if secureUrl.starts(with: "https://") {
                    guard let i = selectedImages.firstIndex(where: { $0.id == imageId }) else { return }

                    selectedImages[i].imageUrl = secureUrl
                    selectedImages[i].isUploading = false

                    saveImageUrlToFirestore(url: secureUrl)
                } else {
                    print("Invalid URL format: \(secureUrl)")
                    selectedImages.remove(at: index)
                }
            }
        }
    }
    private func cropImageToVerticalRectangle(_ image: UIImage, aspectRatio: CGFloat = 3.0/4.0) -> UIImage? {
        let originalWidth = image.size.width
        let originalHeight = image.size.height

        guard originalWidth > 0, originalHeight > 0 else {
            print("Invalid image dimensions")
            return nil
        }

        let originalAspectRatio = originalWidth / originalHeight
        var cropWidth: CGFloat = 0
        var cropHeight: CGFloat = 0

        if originalAspectRatio > aspectRatio {
            cropWidth = originalHeight * aspectRatio
            cropHeight = originalHeight
        } else {
            cropWidth = originalWidth
            cropHeight = originalWidth / aspectRatio
        }

        guard cropWidth > 0, cropHeight > 0 else {
            print("Invalid crop dimensions")
            return nil
        }

        let xOffset = max(0, (originalWidth - cropWidth) / 2)
        let yOffset = max(0, (originalHeight - cropHeight) / 2)

        let cropRect = CGRect(
            x: xOffset,
            y: yOffset,
            width: min(cropWidth, originalWidth),
            height: min(cropHeight, originalHeight)
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            print("Failed to crop image")
            return nil
        }

        return UIImage(cgImage: cgImage)
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
            guard let url = URL(string: urlString) else { continue }
            
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let uiImage = UIImage(data: data) else { return }
                
                DispatchQueue.main.async {
                    selectedImages.append(SelectedImage(image: uiImage, isUploading: false, imageUrl: urlString))
                }
            }.resume()
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


private func cropImageToVerticalRectangle(_ image: UIImage) -> UIImage? {
    let targetSize = CGSize(width: 1080, height: 1440)
    let aspectRatio: CGFloat = 3.0/4.0
    
    // First resize the image
    guard let resizedImage = image.resized(toWidth: targetSize.width) else {
        return nil
    }
    
    // Then perform cropping
    let originalWidth = resizedImage.size.width
    let originalHeight = resizedImage.size.height
    
    guard originalWidth > 0, originalHeight > 0 else {
        print("Invalid image dimensions")
        return nil
    }
    
    let originalAspectRatio = originalWidth / originalHeight
    var cropWidth: CGFloat = 0
    var cropHeight: CGFloat = 0
    
    if originalAspectRatio > aspectRatio {
        cropWidth = originalHeight * aspectRatio
        cropHeight = originalHeight
    } else {
        cropWidth = originalWidth
        cropHeight = originalWidth / aspectRatio
    }
    
    guard cropWidth > 0, cropHeight > 0 else {
        print("Invalid crop dimensions")
        return nil
    }
    
    let xOffset = max(0, (originalWidth - cropWidth) / 2)
    let yOffset = max(0, (originalHeight - cropHeight) / 2)
    
    let cropRect = CGRect(
        x: xOffset,
        y: yOffset,
        width: min(cropWidth, originalWidth),
        height: min(cropHeight, originalHeight)
    )
    
    guard let cgImage = resizedImage.cgImage?.cropping(to: cropRect) else {
        print("Failed to crop image")
        return nil
    }
    
    return UIImage(cgImage: cgImage)
}
extension UIImage {
    func normalizedImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
    
    // Keep your existing extensions together
    func convertHEIFToJpeg() -> Data? {
        var imageData: Data?
        if let data = self.jpegData(compressionQuality: 0.7) {
            imageData = data
        } else if let cgImage = self.cgImage {
            let ciImage = CIImage(cgImage: cgImage)
            let context = CIContext()
            imageData = context.jpegRepresentation(
                of: ciImage,
                colorSpace: CGColorSpaceCreateDeviceRGB(),
                options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.7]
            )
        }
        return imageData
    }
    
    func resized(toWidth width: CGFloat) -> UIImage? {
        let canvasSize = CGSize(
            width: width,
            height: CGFloat(ceil(width/size.width * size.height))
        )
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: canvasSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    static func downsample(imageData: Data, to pointSize: CGSize) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimension = max(pointSize.width, pointSize.height)
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ] as CFDictionary
        
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        
        return UIImage(cgImage: downsampledImage)
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
