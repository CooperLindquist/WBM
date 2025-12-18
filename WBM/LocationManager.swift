import CoreLocation
import FirebaseFirestore
import FirebaseAuth

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation? {
        didSet {
            if let location = userLocation {
                saveLocationToFirestore(location)
            }
        }
    }

    override init() {
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

    private func saveLocationToFirestore(_ location: CLLocation) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        Firestore.firestore().collection("users").document(currentUserID).setData([
            "location": ["latitude": lat, "longitude": lon]
        ], merge: true) { error in
            if let error = error {
                print("Error saving location: \(error.localizedDescription)")
            } else {
                print("User location saved to Firestore.")
            }
        }
    }
}
