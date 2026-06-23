//
//  SwipeAlgorithm.swift
//  WBM
//
//  Scores and sorts candidate users for the swipe stack.
//  Higher score = shown first.
//
//  Score breakdown (max ~110):
//    Spotlight active        +40
//    Premium user            +10
//    Ratings (avg of 3)      0–30
//    Recently active         0–20
//    Profile completeness    0–10
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct SwipeAlgorithm {

    // MARK: - Public Entry Point

    /// Takes a raw list of candidate users and returns them sorted best-first,
    /// with a small shuffle within score tiers so the feed doesn't feel mechanical.
    static func rank(_ users: [User], spotlightedIDs: Set<String>) -> [User] {
        let scored = users.map { user -> (User, Double) in
            let score = computeScore(for: user, spotlightedIDs: spotlightedIDs)
            return (user, score)
        }

        // Group into tiers (every 10 points), shuffle within each tier,
        // then flatten — this gives smart ordering with natural variety.
        let sorted = scored.sorted { $0.1 > $1.1 }
        let tiered = Dictionary(grouping: sorted) { Int($0.1 / 10) }
        let result = tiered.keys.sorted(by: >).flatMap { key -> [User] in
            tiered[key]!.map { $0.0 }.shuffled()
        }

        // Stack is consumed from the END (users.last is shown on top),
        // so we reverse so highest-scored users appear first.
        return result.reversed()
    }

    // MARK: - Scoring

    static func computeScore(for user: User, spotlightedIDs: Set<String>) -> Double {
        var score: Double = 0

        // Spotlight boost — biggest signal, user paid/earned to be seen
        if spotlightedIDs.contains(user.id) {
            score += 40
        }

        // Premium boost
        if user.premium {
            score += 10
        }

        // Ratings — average the three categories, scale to 0–30
        let ratingScore = averageRatingScore(user)
        score += ratingScore

        // Recency — scale to 0–20 based on how recently active
        let recencyScore = recencyScore(user)
        score += recencyScore

        // Profile completeness — scale to 0–10
        let completenessScore = completenessScore(user)
        score += completenessScore

        return score
    }

    // MARK: - Sub-scores

    /// Average of trueToLooks, personality, communication ratings → 0–30
    private static func averageRatingScore(_ user: User) -> Double {
        let ratings = [user.trueToLooksRating, user.personalityRating, user.communicationRating]
            .compactMap { $0 }
        guard !ratings.isEmpty else { return 0 }
        let avg = ratings.reduce(0, +) / Double(ratings.count) // 0–5 scale
        return (avg / 5.0) * 30.0
    }

    /// How recently the user was active → 0–20
    /// 0–1 hour ago:   20
    /// 1–6 hours:      15
    /// 6–24 hours:     10
    /// 1–3 days:        5
    /// 3–7 days:        2
    /// Over a week:     0
    private static func recencyScore(_ user: User) -> Double {
        guard let lastActive = user.lastActive else { return 5 } // unknown → neutral
        let hoursAgo = Date().timeIntervalSince(lastActive) / 3600

        switch hoursAgo {
        case ..<1:    return 20
        case ..<6:    return 15
        case ..<24:   return 10
        case ..<72:   return 5
        case ..<168:  return 2
        default:      return 0
        }
    }

    /// How complete the profile is → 0–10
    /// (internal, not private — reused by AutoSpotlight for candidate qualification)
    static func completenessScore(_ user: User) -> Double {
        var points: Double = 0
        if let bio = user.bio, !bio.isEmpty         { points += 2 }
        if user.imageURLs.count >= 3                { points += 3 }
        else if user.imageURLs.count >= 2           { points += 1 }
        if user.height != nil                       { points += 1 }
        if user.weight != nil                       { points += 1 }
        if user.relationshipGoal != nil             { points += 1 }
        if let langs = user.languages, !langs.isEmpty { points += 1 }
        return points
    }
}
