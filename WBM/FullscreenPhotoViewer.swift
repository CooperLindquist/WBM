import SwiftUI
import SDWebImageSwiftUI

struct FullscreenPhotoViewer: View {

    let photoURLs: [String]
    let selectedIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int

    init(photoURLs: [String], selectedIndex: Int) {
        self.photoURLs = photoURLs
        self.selectedIndex = selectedIndex
        _currentIndex = State(initialValue: selectedIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(photoURLs.indices, id: \.self) { index in
                    WebImage(url: URL(string: photoURLs[index]))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .tag(index)
                        .scaleEffect(1.0)
                        .padding()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
