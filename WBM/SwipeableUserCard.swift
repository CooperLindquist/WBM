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
            CompactUserCardView(
                user: user,
                onInfoTapped: onInfoTapped,
                onSkip: onSkip,
                onApprove: onApprove
            )
            
            // ❤️ LIKE overlay
            if offset.width > 40 && !canApprove {
                Text("OUT OF DIAMONDS")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
            
        
                Text("LIKE")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(-20))
                    .offset(x: -60, y: 40)
            }
            
            // ❌ NOPE overlay
            if offset.width < -40 {
                Text("NOPE")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 4)
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: 60, y: 40)
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
                    }
                    else if value.translation.width < -swipeThreshold {
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
