import SwiftUI
import Firebase
import FirebaseAuth
import PhotosUI
import SDWebImageSwiftUI
import Cloudinary

struct PhotoManagerView: View {

    @Environment(\.dismiss) private var dismiss
    @Binding var photoURLs: [String]

    @State private var showingImageViewer = false
    @State private var selectedIndex = 0
    @State private var photoItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(photoURLs.indices, id: \.self) { index in
                    HStack(spacing: 15) {

                        // Photo thumbnail
                        WebImage(url: URL(string: photoURLs[index]))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                selectedIndex = index
                                showingImageViewer = true
                            }

                        Text("Drag to reorder")
                            .foregroundColor(.gray)

                        Spacer()

                        // Delete button
                        Button(role: .destructive) {
                            deletePhoto(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
                .onMove(perform: move)
            }
            .navigationTitle("Your Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                // Done
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        saveOrder()
                        dismiss()
                    }
                }

                // Add photo
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $photoItems,
                        maxSelectionCount: 6 - photoURLs.count,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                    }
                }

                // Edit reorder
                ToolbarItem(placement: .bottomBar) {
                    EditButton()
                }
            }
        }
        .onChange(of: photoItems) { _, newItems in
            uploadNewPhotos(from: newItems)
        }
        .fullScreenCover(isPresented: $showingImageViewer) {
            FullscreenPhotoViewer(
                photoURLs: photoURLs,
                selectedIndex: selectedIndex
            )
        }
    }

    // MARK: - Reorder
    private func move(from source: IndexSet, to destination: Int) {
        photoURLs.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Delete
    private func deletePhoto(at index: Int) {
        let removedURL = photoURLs.remove(at: index)
        removeFromFirestore(url: removedURL)
    }

    private func removeFromFirestore(url: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData([
                "profileImageURLs": FieldValue.arrayRemove([url])
            ])
    }

    // MARK: - Save Order
    private func saveOrder() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData([
                "profileImageURLs": photoURLs
            ])
    }

    // MARK: - Upload New Photos
    private func uploadNewPhotos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                DispatchQueue.main.async {
                    if case .success(let data?) = result,
                       let image = UIImage(data: data),
                       let jpeg = image.jpegData(compressionQuality: 0.8) {

                        uploadToCloudinary(data: jpeg)
                    }
                }
            }
        }
        photoItems = []
    }

    private func uploadToCloudinary(data: Data) {
        let cloudinary = CLDCloudinary(configuration:
            CLDConfiguration(cloudName: "dfxodj9gk", apiKey: "998259646284382")
        )

        cloudinary.createUploader().upload(
            data: data,
            uploadPreset: "profile pics"
        ) { result, _ in
            DispatchQueue.main.async {
                if let url = result?.secureUrl {
                    photoURLs.append(url)
                    saveOrder()
                }
            }
        }
    }
}
