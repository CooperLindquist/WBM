//
//  AutoSpotlight.swift
//  WBM
//
//  Automatic ("algorithmic") Spotlight boosts — separate from and
//  complementary to manual, diamond/premium-driven Spotlight.
//
//  Manual Spotlight is a monetizable feature: a user actively spends a
//  resource to get boosted. Automatic Spotlight solves a different
//  problem — giving under-exposed but reasonably complete profiles a
//  periodic visibility boost, so the app doesn't become a rich-get-richer
//  popularity contest where only already-popular users get shown.
//
//  Selection criteria (roughly inverse of SwipeAlgorithm's ranking):
//    - Low feedAppearanceCount (hasn't been shown to many people lately)
//    - Recently active (no point boosting an inactive/abandoned account)
//    - Reasonably complete profile (boosting an empty profile helps no one)
//    - Not already in Spotlight (manual or automatic)
//
//  Spotlight documents created by this engine are tagged "source": "auto"
//  so they're distinguishable from manually-activated ones in Firestore,
//  even though they render identically in SpotlightView.
//

import Foundation
import FirebaseFirestore

struct AutoSpotlight {

    /// How many automatically-boosted slots should exist at once.
    /// Kept deliberately small — this is a supplement to manual Spotlight,
    /// not a replacement for it.
    static let maxAutoSlots = 5

    /// Only consider users active within this window. An abandoned account
    /// getting boosted helps no one.
    private static let activeWithinDays: TimeInterval = 14 * 24 * 60 * 60

    /// Minimum completeness score (see SwipeAlgorithm) to qualify.
    /// Out of a possible 10 — this is intentionally a low bar so reasonably
    /// filled-out profiles qualify, while empty/abandoned ones don't.
    private static let minCompletenessScore: Double = 4

    /// Checks how many auto-boosted slots are currently active, and tops up
    /// to `maxAutoSlots` if there's room. Call this opportunistically (e.g.
    /// whenever SpotlightView loads) — same pattern as the expired-doc cleanup.
    static func topUpIfNeeded(excludingUserID currentUserID: String) {
        let spotlightRef = Firestore.firestore().collection("Spotlight")
        let now = Date()

        spotlightRef
            .whereField("expiresAt", isGreaterThan: Timestamp(date: now))
            .whereField("source", isEqualTo: "auto")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("AutoSpotlight: error checking active auto slots: \(error.localizedDescription)")
                    return
                }

                let activeAutoCount = snapshot?.documents.count ?? 0
                let slotsAvailable = maxAutoSlots - activeAutoCount
                guard slotsAvailable > 0 else { return }

                // Also need every currently-spotlighted ID (manual or auto) so
                // we never double-boost someone already visible.
                spotlightRef
                    .whereField("expiresAt", isGreaterThan: Timestamp(date: now))
                    .getDocuments { allSnapshot, error in
                        guard error == nil else { return }
                        let allActiveIDs = Set(allSnapshot?.documents.map { $0.documentID } ?? [])

                        findCandidates(excluding: allActiveIDs.union([currentUserID])) { candidates in
                            let toBoost = candidates.prefix(slotsAvailable)
                            for user in toBoost {
                                activate(userID: user.id)
                            }
                        }
                    }
            }
    }

    // MARK: - Candidate selection

    private static func findCandidates(excluding excludedIDs: Set<String>, completion: @escaping ([User]) -> Void) {
        let cutoff = Date().addingTimeInterval(-activeWithinDays)

        // Pull a batch of recently-active users, then score/filter client-side.
        // (Firestore can't combine "low feedAppearanceCount" + "recently active"
        // into a single indexed query without a composite index tailored to
        // this exact pair of fields, so we fetch a reasonably-sized recent-activity
        // batch and rank within it instead.)
        Firestore.firestore().collection("users")
            .whereField("lastActive", isGreaterThan: Timestamp(date: cutoff))
            .order(by: "lastActive", descending: true)
            .limit(to: 100)
            .getDocuments { snapshot, error in
                guard error == nil, let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let candidates = documents.compactMap { doc -> User? in
                    guard !excludedIDs.contains(doc.documentID) else { return nil }
                    return User(id: doc.documentID, data: doc.data())
                }

                let qualified = candidates.filter { user in
                    SwipeAlgorithm.completenessScore(user) >= minCompletenessScore
                }

                // Sort by least-shown first — the whole point of this feature.
                let ranked = qualified.sorted { lhs, rhs in
                    if lhs.feedAppearanceCount != rhs.feedAppearanceCount {
                        return lhs.feedAppearanceCount < rhs.feedAppearanceCount
                    }
                    // Tie-break: whoever was shown longest ago (or never) goes first.
                    let lhsDate = lhs.lastShownInFeedAt ?? .distantPast
                    let rhsDate = rhs.lastShownInFeedAt ?? .distantPast
                    return lhsDate < rhsDate
                }

                completion(ranked)
            }
    }

    // MARK: - Activation

    private static func activate(userID: String, duration: TimeInterval = 6 * 60 * 60) {
        let ref = Firestore.firestore().collection("Spotlight").document(userID)
        ref.setData([
            "userID": userID,
            "expiresAt": Date().addingTimeInterval(duration),
            "source": "auto"
        ])
    }
}
