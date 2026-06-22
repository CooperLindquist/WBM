//
//  PhotoGridEditor.swift
//  WBM
//
//  Shared, app-themed photo grid used by EditProfileView, OnboardingView,
//  and the standalone photo manager. Replaces three separate ad-hoc
//  layouts (a horizontal scroll in EditProfileView/OnboardingView, and a
//  plain native List with EditButton in the old PhotoManagerView).
//
//  Long-press and drag a tile to reorder. Tap the trash icon to delete.
//  Failed uploads show a retry button instead of silently disappearing.
//

import SwiftUI
import PhotosUI

struct PhotoGridEditor: View {
    @ObservedObject var manager: PhotoUploadManager
    let maxPhotos: Int
    var onURLAdded: (String) -> Void = { _ in }

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var draggingItem: UploadablePhoto?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(manager.photos) { photo in
                    tile(for: photo)
                }

                if manager.photos.count < maxPhotos {
                    addTile
                }
            }

            Text("Drag a photo to reorder \u{00B7} First photo is your main profile picture")
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
        }
        .onChange(of: photoItems) { _, newItems in
            manager.handlePicked(newItems, onURLAdded: onURLAdded)
            photoItems = []
        }
    }

    // MARK: - Tile

    private func tile(for photo: UploadablePhoto) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))

            if photo.image.size != .zero {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)

            if photo.isUploading {
                ZStack {
                    Color.black.opacity(0.45)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if photo.didFail {
                ZStack {
                    Color.black.opacity(0.55)
                    Button(action: { manager.retry(photo, onURLAdded: onURLAdded) }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                            Text("Retry")
                                .font(.caption2.bold())
                        }
                        .foregroundColor(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Delete button, top-right
            VStack {
                HStack {
                    Spacer()
                    Button(action: { manager.remove(photo) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 22, height: 22))
                    }
                    .padding(6)
                }
                Spacer()
            }

            // "Main photo" badge on the first tile
            if manager.photos.first?.id == photo.id {
                VStack {
                    Spacer()
                    HStack {
                        Text("MAIN")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                        Spacer()
                    }
                    .padding(6)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .opacity(draggingItem?.id == photo.id ? 0.5 : 1.0)
        .onDrag {
            draggingItem = photo
            return NSItemProvider(object: photo.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: PhotoDropDelegate(
            target: photo,
            photos: manager.photos,
            draggingItem: $draggingItem,
            manager: manager
        ))
    }

    private var addTile: some View {
        PhotosPicker(
            selection: $photoItems,
            maxSelectionCount: maxPhotos - manager.photos.count,
            matching: .images
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(.white.opacity(0.5))

                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Add")
                        .font(.caption.bold())
                }
                .foregroundColor(.white.opacity(0.85))
            }
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
        }
    }
}

// MARK: - Drag to Reorder

private struct PhotoDropDelegate: DropDelegate {
    let target: UploadablePhoto
    let photos: [UploadablePhoto]
    @Binding var draggingItem: UploadablePhoto?
    let manager: PhotoUploadManager

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != target.id,
              let fromIndex = photos.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = photos.firstIndex(where: { $0.id == target.id })
        else { return }

        manager.move(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
    }
}
