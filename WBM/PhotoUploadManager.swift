//
//  PhotoUploadManager.swift
//  WBM
//
//  Single shared photo-upload pipeline for the whole app. Previously
//  EditProfileView, OnboardingView, and PhotoManagerView each had their
//  own near-duplicate copy of this logic with subtly different crop
//  ratios, compression settings, and — critically — mismatched Cloudinary
//  upload preset names ("profile pics" vs "profile_pics"), meaning photos
//  uploaded from one screen could silently fail depending on which
//  preset actually existed in the Cloudinary dashboard.
//
//  Cloudinary upload preset confirmed from dashboard: "profile pics"
//  (Settings → Upload → Upload presets, cloud name dfxodj9gk).
//

import SwiftUI
import PhotosUI
import Cloudinary
import FirebaseAuth
import FirebaseFirestore
import SDWebImage

/// One slot in the photo grid — either a locally-picked image still uploading,
/// or a finished photo with a Cloudinary URL.
struct UploadablePhoto: Identifiable, Equatable {
    let id: UUID
    var image: UIImage
    var remoteURL: String?
    var isUploading: Bool
    var didFail: Bool = false

    static func == (lhs: UploadablePhoto, rhs: UploadablePhoto) -> Bool { lhs.id == rhs.id }
}

final class PhotoUploadManager: ObservableObject {

    // Confirmed against Cloudinary dashboard (Settings → Upload → Upload presets):
    // the real preset is named "profile pics" (lowercase, with a space).
    static let uploadPreset = "profile pics"
    private static let cloudName = "dfxodj9gk"
    private static let apiKey = "998259646284382"

    private let cloudinary = CLDCloudinary(
        configuration: CLDConfiguration(cloudName: cloudName, apiKey: apiKey)
    )

    @Published var photos: [UploadablePhoto] = []
    @Published var isUploadingAny: Bool = false

    /// Loads existing photo URLs (e.g. when opening the editor) into the grid,
    /// using SDWebImage's cache so repeat opens don't re-download from Cloudinary.
    func loadExisting(urls: [String]) {
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            let id = UUID()
            // Insert a placeholder immediately so ordering matches `urls`
            photos.append(UploadablePhoto(id: id, image: UIImage(), remoteURL: urlString, isUploading: true))

            SDWebImageManager.shared.loadImage(
                with: url,
                options: [.continueInBackground, .highPriority],
                progress: nil
            ) { [weak self] image, _, _, _, _, _ in
                guard let self = self, let image = image else { return }
                DispatchQueue.main.async {
                    guard let index = self.photos.firstIndex(where: { $0.id == id }) else { return }
                    self.photos[index].image = image
                    self.photos[index].isUploading = false
                }
            }
        }
    }

    /// Accepts freshly picked PhotosPickerItems, crops/compresses/uploads each one.
    func handlePicked(_ items: [PhotosPickerItem], onURLAdded: @escaping (String) -> Void) {
        guard !items.isEmpty else { return }
        isUploadingAny = true

        for item in items {
            let id = UUID()
            photos.append(UploadablePhoto(id: id, image: UIImage(), isUploading: true))

            item.loadTransferable(type: Data.self) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let data):
                    guard let data = data, let rawImage = UIImage(data: data) else {
                        self.markFailed(id)
                        return
                    }

                    // Crop + compress off the main thread — these are CPU-bound.
                    DispatchQueue.global(qos: .userInitiated).async {
                        let normalized = rawImage.fixedOrientation()
                        guard let cropped = self.cropToPortrait(normalized),
                              let jpeg = cropped.jpegData(compressionQuality: 0.8) ?? cropped.heicFallbackJPEG()
                        else {
                            DispatchQueue.main.async { self.markFailed(id) }
                            return
                        }

                        DispatchQueue.main.async {
                            guard let index = self.photos.firstIndex(where: { $0.id == id }) else { return }
                            self.photos[index].image = cropped
                            self.upload(jpeg, id: id, onURLAdded: onURLAdded)
                        }
                    }

                case .failure:
                    self.markFailed(id)
                }
            }
        }
    }

    /// Removes a photo locally and from Firestore. Safe to call mid-upload.
    func remove(_ photo: UploadablePhoto) {
        photos.removeAll { $0.id == photo.id }
        if let url = photo.remoteURL {
            removeFromFirestore(url: url)
        }
    }

    /// Reorders the grid and persists the new order to Firestore.
    func move(from source: IndexSet, to destination: Int) {
        photos.move(fromOffsets: source, toOffset: destination)
        saveOrderToFirestore()
    }

    /// Retry a failed upload without the user having to re-pick the photo.
    func retry(_ photo: UploadablePhoto, onURLAdded: @escaping (String) -> Void) {
        guard let index = photos.firstIndex(where: { $0.id == photo.id }) else { return }
        photos[index].didFail = false
        photos[index].isUploading = true

        guard let jpeg = photo.image.jpegData(compressionQuality: 0.8) else {
            markFailed(photo.id)
            return
        }
        upload(jpeg, id: photo.id, onURLAdded: onURLAdded)
    }

    // MARK: - Private

    private func upload(_ data: Data, id: UUID, onURLAdded: @escaping (String) -> Void) {
        cloudinary.createUploader().upload(
            data: data,
            uploadPreset: Self.uploadPreset
        ) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let index = self.photos.firstIndex(where: { $0.id == id }) else { return }

                if let error = error {
                    print("Cloudinary upload failed: \(error.localizedDescription)")
                    self.photos[index].isUploading = false
                    self.photos[index].didFail = true
                    self.refreshUploadingFlag()
                    return
                }

                guard let url = result?.secureUrl, url.hasPrefix("https://") else {
                    self.photos[index].isUploading = false
                    self.photos[index].didFail = true
                    self.refreshUploadingFlag()
                    return
                }

                self.photos[index].remoteURL = url
                self.photos[index].isUploading = false
                self.saveURLToFirestore(url)
                onURLAdded(url)
                self.refreshUploadingFlag()
            }
        }
    }

    private func markFailed(_ id: UUID) {
        DispatchQueue.main.async {
            guard let index = self.photos.firstIndex(where: { $0.id == id }) else { return }
            self.photos[index].isUploading = false
            self.photos[index].didFail = true
            self.refreshUploadingFlag()
        }
    }

    private func refreshUploadingFlag() {
        isUploadingAny = photos.contains { $0.isUploading }
    }

    /// Standardized 3:4 portrait crop — matches the aspect ratio used by
    /// profile cards everywhere else in the app.
    private func cropToPortrait(_ image: UIImage, aspectRatio: CGFloat = 3.0 / 4.0) -> UIImage? {
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return nil }

        let currentAspect = width / height
        var cropRect: CGRect

        if currentAspect > aspectRatio {
            let newWidth = height * aspectRatio
            cropRect = CGRect(x: (width - newWidth) / 2, y: 0, width: newWidth, height: height)
        } else {
            let newHeight = width / aspectRatio
            cropRect = CGRect(x: 0, y: (height - newHeight) / 2, width: width, height: newHeight)
        }

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func saveURLToFirestore(_ url: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .updateData(["profileImageURLs": FieldValue.arrayUnion([url])]) { error in
                if let error = error {
                    print("Error saving image URL: \(error.localizedDescription)")
                }
            }
    }

    private func removeFromFirestore(url: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .updateData(["profileImageURLs": FieldValue.arrayRemove([url])]) { error in
                if let error = error {
                    print("Error removing image URL: \(error.localizedDescription)")
                }
            }
    }

    private func saveOrderToFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let orderedURLs = photos.compactMap { $0.remoteURL }
        Firestore.firestore().collection("users").document(uid)
            .updateData(["profileImageURLs": orderedURLs]) { error in
                if let error = error {
                    print("Error saving photo order: \(error.localizedDescription)")
                }
            }
    }
}

// MARK: - Shared UIImage helpers

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }

    /// Fallback path for HEIC sources where jpegData(quality:) can occasionally
    /// return nil — re-encodes through Core Image instead.
    func heicFallbackJPEG() -> Data? {
        guard let cgImage = cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        return context.jpegRepresentation(
            of: ciImage,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.7]
        )
    }
}
