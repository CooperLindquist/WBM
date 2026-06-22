//
//  Review.swift
//  WBM
//
//  Lightweight model for the written reviews stored in each user's
//  `reviews` array field (written by RateUserView.submitWrittenReview).
//

import Foundation

struct Review: Identifiable {
    let id = UUID()
    let text: String
    let isAnonymous: Bool
    let reviewerID: String

    init?(data: [String: Any]) {
        guard let text = data["review"] as? String, !text.isEmpty else { return nil }
        self.text = text
        self.isAnonymous = data["isAnonymous"] as? Bool ?? false
        self.reviewerID = data["reviewerID"] as? String ?? ""
    }
}
