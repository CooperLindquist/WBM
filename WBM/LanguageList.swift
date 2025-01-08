//
//  LanguageList.swift
//  WBM
//
//  Created by Cooper Lindquist on 1/3/25.
//


import SwiftUI

struct LanguageList: View {
    @Binding var selectedLanguages: [String]
    @Environment(\.presentationMode) var presentationMode // Add this to manage dismissal

    var body: some View {
        NavigationView {
            List {
                ForEach([
                    "English", "Spanish", "French", "German", "Mandarin", "Japanese", "Korean",
                    "Italian", "Portuguese", "Russian", "Hindi", "Arabic", "Dutch", "Swedish",
                    "Turkish", "Greek", "Thai", "Vietnamese", "Bengali", "Urdu", "Polish", "Czech"
                ], id: \.self) { language in
                    MultipleSelectionRow(language: language)
                }
            }
            .navigationTitle("Select Languages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss() // Dismiss on "Done"
                    }
                }
            }
        }
    }

    private func MultipleSelectionRow(language: String) -> some View {
        Button(action: {
            if selectedLanguages.contains(language) {
                selectedLanguages.removeAll { $0 == language }
            } else {
                selectedLanguages.append(language)
            }
        }) {
            HStack {
                Text(language)
                Spacer()
                if selectedLanguages.contains(language) {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
