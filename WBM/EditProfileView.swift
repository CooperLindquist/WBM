import SwiftUI
import Firebase
import PhotosUI
import FirebaseAuth
import Cloudinary

enum EditProfileMode {
    case initialSetup   // app just launched, no profile yet
    case editing        // user tapped "Edit Profile"
}

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {

    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(
        data: Data,
        spacing: CGFloat = 10,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {

        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }

    }

    private func generateContent(in geometry: GeometryProxy) -> some View {

        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {

            ForEach(Array(data), id: \.self) { item in

                content(item)
                    .padding(.all, 4)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item == data.first {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }

                    .alignmentGuide(.top) { dimension in
                        let result = height
                        if item == data.first {
                            height = 0
                        }
                        return result
                    }

            }

        }

    }

}
struct ChipSelection: View {

    let title: String
    let options: [String]
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 110), spacing: 10)
    ]

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {

                ForEach(options, id: \.self) { option in

                    Text(option)
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == option ?
                            Color.blue :
                            Color.gray.opacity(0.2)
                        )
                        .foregroundColor(
                            selection == option ? .white : .black
                        )
                        .clipShape(Capsule())
                        .onTapGesture {
                            selection = option
                        }

                }

            }

        }
    }
}
struct EditProfileView: View {
    let mode: EditProfileMode
    let onSave: (() -> Void)?

    
    @EnvironmentObject var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var religion: String = ""
    @State private var ethnicity: String = ""
    @State private var drinking: String = ""
    @State private var smoking: String = ""
    @State private var cannabis: String = ""
    @State private var politics: String = ""
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
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isShowingLanguageList = false
    @State private var age: String = ""
    struct ProfileImage: Identifiable {
        let id = UUID()
        var image: UIImage
        var isUploading: Bool = true
    }

    @State private var selectedImages: [ProfileImage] = []

    
    private let relationshipGoals = ["Short-term", "Long-term", "Friends", "Marriage"]
    private let cloudinary = CLDCloudinary(configuration: CLDConfiguration(cloudName: "dfxodj9gk", apiKey: "998259646284382"))
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                               startPoint: .top,
                               endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 25) {
                        HeaderView

                        PersonalInfoSection
                        AgeSection
                        PhysicalAttributesSection
                        GenderSection
                        RelationshipGoalSection
                        LifestyleSection
                        LanguageSelectionSection
                        ProfilePicturesSection

                        SaveButton
                    }
                    .padding(.horizontal)
                }
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
    private var AgeSection: some View {
        SectionView(title: "Age") {
            TextField("Enter your age", text: $age)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    HStack {
                        Spacer()
                        Text("years")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                )
        }
    }
    
    private var HeaderView: some View {
        VStack {
            Text("Edit Profile")
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
            VStack(spacing: 12) { // Tighter spacing
                TextField("Name", text: $name)
                    .textFieldStyle(EnhancedTextFieldStyle())
                
                TextField("Bio", text: $bio)
                    .textFieldStyle(EnhancedTextFieldStyle())
            }
        }
    }
    
    private var PhysicalAttributesSection: some View {
        SectionView(title: "Physical Attributes") {
            VStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Height")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack {
                        Text("\(height / 12)'\(height % 12)\"")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Adjust slider")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    Slider(value: Binding(
                        get: { Double(height) },
                        set: { height = Int($0) }
                    ), in: 48...96, step: 1) // More reasonable height range
                }
                
                VStack(alignment: .leading) {
                    Text("Weight")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    HStack {
                        Text("\(Int(weight)) lbs")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Adjust slider")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    Slider(value: $weight, in: 80...300, step: 1) // Adjusted weight range
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
    private var LifestyleSection: some View {
        SectionView(title: "Lifestyle & Beliefs") {
            VStack(alignment: .leading, spacing: 25) {

                ChipSelection(
                    title: "Religion",
                    options: religions,
                    selection: $religion
                )

                ChipSelection(
                    title: "Ethnicity",
                    options: ethnicities,
                    selection: $ethnicity
                )

                ChipSelection(
                    title: "Drinking",
                    options: drinkingOptions,
                    selection: $drinking
                )

                ChipSelection(
                    title: "Smoking",
                    options: smokingOptions,
                    selection: $smoking
                )

                ChipSelection(
                    title: "Cannabis",
                    options: cannabisOptions,
                    selection: $cannabis
                )

                ChipSelection(
                    title: "Politics",
                    options: politicsOptions,
                    selection: $politics
                )

            }
        }
    }
    private let religions = [
        "Christian", "Catholic", "Jewish", "Muslim",
        "Hindu", "Buddhist", "Agnostic", "Atheist", "Other"
    ]

    private let ethnicities = [
        "White", "Black", "Hispanic / Latino", "Asian",
        "Middle Eastern", "Native American", "Mixed", "Other"
    ]

    private let drinkingOptions = [
        "Never", "Socially", "Often"
    ]

    private let smokingOptions = [
        "Never", "Sometimes", "Regularly"
    ]

    private let cannabisOptions = [
        "Never", "Sometimes", "Often"
    ]

    private let politicsOptions = [
        "Liberal", "Moderate", "Conservative", "Not Political"
    ]
    
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
                        ForEach(selectedImages) { item in
                            VStack {
                                ZStack {
                                    Image(uiImage: item.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    if item.isUploading {
                                        Color.black.opacity(0.4)
                                        ProgressView()
                                    }
                                }

                                Button {
                                    removeProfilePicture(item)
                                } label: {
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
    
    private func removeProfilePicture(_ image: ProfileImage) {
        selectedImages.removeAll { $0.id == image.id }
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
        guard !items.isEmpty else { return }

        isUploadingImages = true
        uploadsInProgress = items.count

        for item in items {
            let profileImage = ProfileImage(image: UIImage(), isUploading: true)
            selectedImages.append(profileImage)
            let id = profileImage.id


            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    guard let index = selectedImages.firstIndex(where: { $0.id == id }) else { return }

                    switch result {
                    case .success(let data):
                        guard let data,
                              let uiImage = UIImage(data: data),
                              let cropped = cropImageToPortrait(uiImage)
                        else {

                            selectedImages.remove(at: index)
                            return
                        }

                        selectedImages[index].image = cropped

                        if let jpeg = cropped.jpegData(compressionQuality: 0.8) {
                            uploadImageToCloudinary(imageData: jpeg, imageID: id)
                        }

                    case .failure:
                        selectedImages.remove(at: index)
                    }
                }
            }
        }
    }

    
    private func uploadImageToCloudinary(imageData: Data, imageID: UUID) {
        cloudinary.createUploader().upload(
            data: imageData,
            uploadPreset: "profile pics"
        ) { result, error in
            DispatchQueue.main.async {
                guard let index = selectedImages.firstIndex(where: { $0.id == imageID }) else { return }

                uploadsInProgress -= 1
                selectedImages[index].isUploading = false

                if let url = result?.secureUrl {
                    saveImageUrlToFirestore(url: url)
                }

                if uploadsInProgress == 0 {
                    isUploadingImages = false
                }
            }
        }
    }

    
    
    private func cropImageToPortrait(_ image: UIImage) -> UIImage? {

        // 1️⃣ Fix orientation first
        let fixedImage = image.fixedOrientation()

        // 2️⃣ iPhone portrait ratio (3:4)
        let targetAspect: CGFloat = 3.0 / 4.0

        let width = fixedImage.size.width
        let height = fixedImage.size.height
        let currentAspect = width / height

        var cropRect: CGRect

        if currentAspect > targetAspect {
            // Image too wide → crop sides
            let newWidth = height * targetAspect
            let xOffset = (width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: height)
        } else {
            // Image too tall → crop top/bottom
            let newHeight = width / targetAspect
            let yOffset = (height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: width, height: newHeight)
        }

        guard let cgImage = fixedImage.cgImage?.cropping(to: cropRect) else {
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
                religion = data["religion"] as? String ?? ""
                ethnicity = data["ethnicity"] as? String ?? ""
                drinking = data["drinking"] as? String ?? ""
                smoking = data["smoking"] as? String ?? ""
                cannabis = data["cannabis"] as? String ?? ""
                politics = data["politics"] as? String ?? ""
                name = data["name"] as? String ?? ""
                bio = data["bio"] as? String ?? ""
                age = data["age"] as? String ?? ""
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
                            selectedImages.append(
                                ProfileImage(image: uiImage, isUploading: false)
                            )

                        }
                    }
                }.resume()
            }
        }
    }
    
    private func saveProfileData() {
        guard let user = Auth.auth().currentUser else {
            print("❌ No authenticated user")
            return
        }

        // Clean age input
        let cleanedAge = age.filter { $0.isNumber }
        let finalAge = cleanedAge.isEmpty ? "" : cleanedAge

        let updatedData: [String: Any] = [
            "name": name,
            "bio": bio,
            "age": finalAge,
            "height": "\(height)",
            "weight": "\(Int(weight))",
            "gender": gender,
            "relationshipGoal": relationshipGoal,
            "languages": selectedLanguages,
            "religion": religion,
            "ethnicity": ethnicity,
            "drinking": drinking,
            "smoking": smoking,
            "cannabis": cannabis,
            "politics": politics,
            "hasCompletedProfile": true   // ✅ THIS FIXES THE LOOP
            
        ]

        Firestore.firestore()
            .collection("users")
            .document(user.uid)
            .setData(updatedData, merge: true) { error in
                if let error = error {
                    print("❌ Error saving profile data: \(error.localizedDescription)")
                    return
                }

                print("✅ Profile saved successfully")

                // 🔥 CRITICAL FIX FOR FIRST-TIME USERS
                if mode == .initialSetup {
                    sessionManager.hasCompletedProfile = true
                }

                // Refresh ProfileView if needed
                onSave?()

                dismiss()


            }
        
    }
    
}
extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}

struct EnhancedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}



