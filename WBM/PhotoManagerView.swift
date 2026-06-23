//
//  PhotoManagerView.swift
//  WBM
//
//  Opened from ProfileView when the user taps their profile photo.
//  Rebuilt to match the app's visual language (gradient background,
//  frosted glass cards) instead of a plain native List, and now shares
//  the same upload/crop/reorder engine as EditProfileView and
//  OnboardingView via PhotoUploadManager + PhotoGridEditor.
//

import SwiftUI
import FirebaseAuth

struct PhotoManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var photoURLs: [String]

    @StateObject private var photoManager = PhotoUploadManager()
    @State private var showingImageViewer = false
    @State private var selectedIndex = 0

    private let maxPhotos = 6

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.pink.opacity(0.5), Color.blue.opacity(0.7)]),
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Photos")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        PhotoGridEditor(manager: photoManager, maxPhotos: maxPhotos)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Manage Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // Only load once — avoids duplicating entries if this view
            // re-renders while already populated.
            if photoManager.photos.isEmpty {
                photoManager.loadExisting(urls: photoURLs)
            }
        }
        .onChange(of: photoManager.photos) { _, newPhotos in
            // Keep the parent's binding (used elsewhere in ProfileView) in sync
            // with whatever order/contents the grid currently has.
            photoURLs = newPhotos.compactMap { $0.remoteURL }
        }
        .fullScreenCover(isPresented: $showingImageViewer) {
            FullscreenPhotoViewer(
                photoURLs: photoURLs,
                selectedIndex: selectedIndex
            )
        }
    }
}
