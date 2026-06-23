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
    let premium: Bool
    let location: CLLocationCoordinate2D?

    // Rating fields (running averages written by RateUserView)
    let trueToLooksRating: Double?
    let personalityRating: Double?
    let communicationRating: Double?

    // Last time the user was active (written on app open/foreground)
    let lastActive: Date?

    // Visibility tracking — used to find under-exposed users for automatic
    // Spotlight boosts. Incremented client-side whenever this profile is
    // included in someone's swipe feed (see SwipeAlgorithm / HomePageView).
    let feedAppearanceCount: Int
    let lastShownInFeedAt: Date?

    init?(id: String, data: [String: Any]) {
        guard let name = data["name"] as? String,
              let imageURLs = data["profileImageURLs"] as? [String], !imageURLs.isEmpty else { return nil }

        self.id = id
        self.name = name
        self.age = data["age"] as? String
        self.bio = data["bio"] as? String
        self.height = data["height"] as? String
        self.weight = data["weight"] as? String
        self.gender = data["gender"] as? String
        self.languages = data["languages"] as? [String]
        self.relationshipGoal = data["relationshipGoal"] as? String
        self.imageURLs = imageURLs
        self.premium = data["premium"] as? Bool ?? false
        self.religion = data["religion"] as? String
        self.ethnicity = data["ethnicity"] as? String
        self.smoking = data["smoking"] as? String
        self.drinking = data["drinking"] as? String

        self.trueToLooksRating   = data["trueToLooks"]    as? Double
        self.personalityRating   = data["personality"]    as? Double
        self.communicationRating = data["communication"]  as? Double
        self.lastActive = (data["lastActive"] as? Timestamp)?.dateValue()
        self.feedAppearanceCount = data["feedAppearanceCount"] as? Int ?? 0
        self.lastShownInFeedAt = (data["lastShownInFeedAt"] as? Timestamp)?.dateValue()

        if let locationData = data["location"] as? [String: Any],
           let lat = locationData["latitude"] as? CLLocationDegrees,
           let lon = locationData["longitude"] as? CLLocationDegrees {
            self.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            self.location = nil
        }
    }

    static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}


