import CoreLocation
import FirebaseFirestore
import FirebaseAuth

// COST OPTIMIZATION: this used to be instantiated fresh (`@StateObject ... =
// LocationManager()`) in BOTH HomePageView and SpotlightView. Since those views
// get torn down and recreated on every tab switch (see SpotlightView's caching
// comment), each switch spun up a brand new CLLocationManager, requested a fresh
// location, and wrote it to Firestore — completely unthrottled, every single
// time. That's what was flooding the console with "User location saved to
// Firestore." A single shared instance means location is only requested/written
// once per app session (or once per throttle window below), no matter how many
// views observe it or how often they're recreated.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation? {
        didSet {
            if let location = userLocation {
                maybeSaveLocationToFirestore(location)
            }
        }
    }

    // Only write to Firestore if the location has moved meaningfully or enough
    // time has passed — mirrors the lastActive throttle pattern used elsewhere
    // in the app. A user's location for matching purposes doesn't need to be
    // precise to the meter or written every time the OS hands back a reading.
    private var lastWrittenLocation: CLLocation?
    private var lastWriteTime: Date = .distantPast
    private let minimumWriteInterval: TimeInterval = 10 * 60 // 10 minutes
    private let minimumDistanceMeters: CLLocationDistance = 500 // ~0.3 miles

    private override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location
        manager.stopUpdatingLocation()
    }

    private func maybeSaveLocationToFirestore(_ location: CLLocation) {
        let now = Date()
        let timeSinceLastWrite = now.timeIntervalSince(lastWriteTime)
        let distanceFromLastWrite = lastWrittenLocation.map { location.distance(from: $0) } ?? .greatestFiniteMagnitude

        guard timeSinceLastWrite > minimumWriteInterval || distanceFromLastWrite > minimumDistanceMeters else {
            return
        }

        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        lastWrittenLocation = location
        lastWriteTime = now

        Firestore.firestore().collection("users").document(currentUserID).setData([
            "location": ["latitude": lat, "longitude": lon]
        ], merge: true) { error in
            if let error = error {
                print("Error saving location: \(error.localizedDescription)")
            }
        }
    }
}
