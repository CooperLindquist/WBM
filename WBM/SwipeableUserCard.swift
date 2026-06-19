import SwiftUI
import UIKit

struct SwipeableUserCard: View {
    let user: User
    let canApprove: Bool
    var onInfoTapped: () -> Void
    var onSkip: () -> Void
    var onApprove: () -> Void

    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            UserCardView(user: user, onInfoTapped: onInfoTapped)

            // ❤️ LIKE overlay
            if offset.width > 40 {
                VStack(spacing: 8) {
                    Text("LIKE")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green, lineWidth: 4)
                        )
                        .rotationEffect(.degrees(-18))

                    if !canApprove {
                        Text("OUT OF DIAMONDS")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(8)
                    }
                }
                .offset(x: -50, y: 60)
            }

            // ❌ NOPE overlay
            if offset.width < -40 {
                Text("NOPE")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.red)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: 50, y: 60)
            }
        }
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                    rotation = Double(value.translation.width / 20)
                }
                .onEnded { value in
                    if value.translation.width > swipeThreshold {
                        if canApprove {
                            swipeRight()
                        } else {
                            resetCard()
                        }
                    } else if value.translation.width < -swipeThreshold {
                        swipeLeft()
                    } else {
                        resetCard()
                    }
                }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: offset)
    }

    private func swipeRight() {
        haptic()
        offset = CGSize(width: 1000, height: 0)
        rotation = 20
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onApprove()
            resetImmediately()
        }
    }

    private func swipeLeft() {
        haptic()
        offset = CGSize(width: -1000, height: 0)
        rotation = -20
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onSkip()
            resetImmediately()
        }
    }

    private func resetCard() {
        offset = .zero
        rotation = 0
    }

    private func resetImmediately() {
        offset = .zero
        rotation = 0
    }

    private func haptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
