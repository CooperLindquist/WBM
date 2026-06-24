//
//  User.swift
//  WBM
//
//  Updated to store subscriptionTier (String) from Firestore instead of
//  the old flat `premium: Bool`. The computed `premium` property is kept
//  for backward-compatibility with any code that still reads it.
//

import Foundation
import CoreLocation
import FirebaseFirestore

struct User: Identifiable, Hashable {
    let id: String
    let age: String?
    let name: String
    let bio: String?
    let height: String?
    let weight: String?
    let gender: String?
    let languages: [String]?
    let relationshipGoal: String?
    let religion: String?
    let ethnicity: String?
    let smoking: String?
    let drinking: String?
    let imageURLs: [String]

    // ── Subscription ─────────────────────────────────────────────────────────
    /// Tier stored as a string in Firestore ("none" / "silver" / "gold" / "diamond").
    let subscriptionTier: SubscriptionTier

    /// Legacy convenience — true for any paid tier.
    var premium: Bool { subscriptionTier > .none }

    // ── Ratings ──────────────────────────────────────────────────────────────
    let trueToLooksRating: Double?
    let personalityRating: Double?
    let communicationRating: Double?

    // ── Activity & feed visibility ────────────────────────────────────────────
    let lastActive: Date?
    let feedAppearanceCount: Int
    let lastShownInFeedAt: Date?

    // ── Location ─────────────────────────────────────────────────────────────
    let location: CLLocationCoordinate2D?

    init?(id: String, data: [String: Any]) {
        guard let name = data["name"] as? String,
              let imageURLs = data["profileImageURLs"] as? [String], !imageURLs.isEmpty else { return nil }

        self.id       = id
        self.name     = name
        self.age      = data["age"]              as? String
        self.bio      = data["bio"]              as? String
        self.height   = data["height"]           as? String
        self.weight   = data["weight"]           as? String
        self.gender   = data["gender"]           as? String
        self.languages       = data["languages"]       as? [String]
        self.relationshipGoal = data["relationshipGoal"] as? String
        self.imageURLs        = imageURLs
        self.religion  = data["religion"]  as? String
        self.ethnicity = data["ethnicity"] as? String
        self.smoking   = data["smoking"]   as? String
        self.drinking  = data["drinking"]  as? String

        // ── Resolve subscription tier ─────────────────────────────────────
        // New docs store a "subscriptionTier" string.
        // Old docs only had "premium": Bool — fall back gracefully.
        if let tierString = data["subscriptionTier"] as? String {
            switch tierString {
            case "silver":  self.subscriptionTier = .silver
            case "gold":    self.subscriptionTier = .gold
            case "diamond": self.subscriptionTier = .diamond
            default:        self.subscriptionTier = .none
            }
        } else {
            // Legacy fallback
            let legacyPremium = data["premium"] as? Bool ?? false
            self.subscriptionTier = legacyPremium ? .silver : .none
        }

        // ── Ratings ───────────────────────────────────────────────────────
        self.trueToLooksRating   = data["trueToLooks"]   as? Double
        self.personalityRating   = data["personality"]   as? Double
        self.communicationRating = data["communication"] as? Double

        // ── Activity ──────────────────────────────────────────────────────
        self.lastActive          = (data["lastActive"]        as? Timestamp)?.dateValue()
        self.feedAppearanceCount = data["feedAppearanceCount"] as? Int ?? 0
        self.lastShownInFeedAt   = (data["lastShownInFeedAt"] as? Timestamp)?.dateValue()

        // ── Location ──────────────────────────────────────────────────────
        if let locationData = data["location"] as? [String: Any],
           let lat = locationData["latitude"]  as? CLLocationDegrees,
           let lon = locationData["longitude"] as? CLLocationDegrees {
            self.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            self.location = nil
        }
    }

    static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
