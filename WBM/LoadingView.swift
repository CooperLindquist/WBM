//
//  LoadingView.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.pink.opacity(0.7), Color.blue.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                Image("WBM") // Use your logo from assets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .shadow(radius: 10)

                Text("Weight-Based Matchmaking")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
            }
        }
    }
}
