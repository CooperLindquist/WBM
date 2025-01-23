import SwiftUI

struct ImageCropperView: View {
    @Binding var image: UIImage
    @Binding var isPresented: Bool
    var aspectRatio: CGFloat = 3.0 / 4.0
    var onCrop: (UIImage) -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            GeometryReader { geo in
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .offset(offset)
                        .scaleEffect(zoomScale)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    offset = CGSize(
                                        width: offset.width + gesture.translation.width,
                                        height: offset.height + gesture.translation.height
                                    )
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoomScale = value.magnitude
                                }
                        )
                        .clipShape(
                            Rectangle()
                                .size(
                                    CGSize(width: geo.size.width, height: geo.size.width / aspectRatio)
                                )
                        )
                }
            }

            VStack {
                Spacer()

                HStack(spacing: 20) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Crop") {
                        let croppedImage = cropImage(image: image, zoomScale: zoomScale, offset: offset, size: CGSize(width: 300, height: 300 / aspectRatio))
                        onCrop(croppedImage)
                        isPresented = false
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
    }

    private func cropImage(image: UIImage, zoomScale: CGFloat, offset: CGSize, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(x: -offset.width, y: -offset.height, width: size.width * zoomScale, height: size.height * zoomScale))
        }
    }
}
