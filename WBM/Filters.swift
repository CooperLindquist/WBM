import Foundation
import CoreLocation
import SwiftUI

// Filters Struct - Updated to support UserDefaults
struct Filters {
    var minWeight: Double
    var maxWeight: Double
    var minHeight: Double
    var maxHeight: Double
    var gender: String?
    var weightFilterEnabled: Bool
    var heightFilterEnabled: Bool
    var genderFilterEnabled: Bool
    var locationFilterEnabled: Bool
    var maxDistance: Double
    var religion: String?
    var ethnicity: String?
    var smoking: String?
    var drinking: String?
    var language: String?
    var relationshipGoal: String?
    var religionFilterEnabled: Bool
    var ethnicityFilterEnabled: Bool
    var smokingFilterEnabled: Bool
    var drinkingFilterEnabled: Bool
    var languageFilterEnabled: Bool
    var relationshipGoalFilterEnabled: Bool

    // Memberwise init with sensible defaults
    init(
        minWeight: Double = 100, maxWeight: Double = 300,
        minHeight: Double = 50,  maxHeight: Double = 84,
        gender: String? = nil,
        weightFilterEnabled: Bool = false,
        heightFilterEnabled: Bool = false,
        genderFilterEnabled: Bool = false,
        locationFilterEnabled: Bool = false,
        maxDistance: Double = 50,
        religion: String? = nil,
        ethnicity: String? = nil,
        smoking: String? = nil,
        drinking: String? = nil,
        language: String? = nil,
        relationshipGoal: String? = nil,
        religionFilterEnabled: Bool = false,
        ethnicityFilterEnabled: Bool = false,
        smokingFilterEnabled: Bool = false,
        drinkingFilterEnabled: Bool = false,
        languageFilterEnabled: Bool = false,
        relationshipGoalFilterEnabled: Bool = false
    ) {
        self.minWeight = minWeight
        self.maxWeight = maxWeight
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.gender = gender
        self.weightFilterEnabled = weightFilterEnabled
        self.heightFilterEnabled = heightFilterEnabled
        self.genderFilterEnabled = genderFilterEnabled
        self.locationFilterEnabled = locationFilterEnabled
        self.maxDistance = maxDistance
        self.religion = religion
        self.ethnicity = ethnicity
        self.smoking = smoking
        self.drinking = drinking
        self.language = language
        self.relationshipGoal = relationshipGoal
        self.religionFilterEnabled = religionFilterEnabled
        self.ethnicityFilterEnabled = ethnicityFilterEnabled
        self.smokingFilterEnabled = smokingFilterEnabled
        self.drinkingFilterEnabled = drinkingFilterEnabled
        self.languageFilterEnabled = languageFilterEnabled
        self.relationshipGoalFilterEnabled = relationshipGoalFilterEnabled
    }
    
    func matches(user: User, currentLocation: CLLocation?) -> Bool {
        if weightFilterEnabled {
            if let weight = Double(user.weight ?? ""), weight < minWeight || weight > maxWeight {
                return false
            }
        }
        if heightFilterEnabled {
            if let height = Double(user.height ?? ""), height < minHeight || height > maxHeight {
                return false
            }
        }
        if genderFilterEnabled {
            if let gender = gender, user.gender != gender {
                return false
            }
        }
        if locationFilterEnabled {
            if let currentLocation = currentLocation, let userLocation = user.location {
                let distanceInMeters = currentLocation.distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude))
                let distanceInMiles = distanceInMeters / 1609.34
                if distanceInMiles > maxDistance {
                    return false
                }
            } else {
                // If the user location is not available, we should exclude this user
                return false
            }
        }
        if religionFilterEnabled {
            if let religion = religion, user.religion != religion {
                return false
            }
        }

        if ethnicityFilterEnabled {
            if let ethnicity = ethnicity, user.ethnicity != ethnicity {
                return false
            }
        }

        if smokingFilterEnabled {
            if let smoking = smoking, user.smoking != smoking {
                return false
            }
        }

        if drinkingFilterEnabled {
            if let drinking = drinking, user.drinking != drinking {
                return false
            }
        }

        if relationshipGoalFilterEnabled {
            if let goal = relationshipGoal, user.relationshipGoal != goal {
                return false
            }
        }
        return true
    }
    
    
    // Save filters to UserDefaults
    func saveFilters() {
        let ud = UserDefaults.standard
        ud.set(minWeight,                  forKey: "minWeight")
        ud.set(maxWeight,                  forKey: "maxWeight")
        ud.set(minHeight,                  forKey: "minHeight")
        ud.set(maxHeight,                  forKey: "maxHeight")
        ud.set(maxDistance,                forKey: "maxDistance")
        ud.set(gender,                     forKey: "gender")
        ud.set(weightFilterEnabled,        forKey: "weightFilterEnabled")
        ud.set(heightFilterEnabled,        forKey: "heightFilterEnabled")
        ud.set(genderFilterEnabled,        forKey: "genderFilterEnabled")
        ud.set(locationFilterEnabled,      forKey: "locationFilterEnabled")
        // Fix #19: these were never being saved — filters reset on every app restart
        ud.set(religion,                   forKey: "religion")
        ud.set(ethnicity,                  forKey: "ethnicity")
        ud.set(smoking,                    forKey: "smoking")
        ud.set(drinking,                   forKey: "drinking")
        ud.set(language,                   forKey: "language")
        ud.set(relationshipGoal,           forKey: "relationshipGoal")
        ud.set(religionFilterEnabled,      forKey: "religionFilterEnabled")
        ud.set(ethnicityFilterEnabled,     forKey: "ethnicityFilterEnabled")
        ud.set(smokingFilterEnabled,       forKey: "smokingFilterEnabled")
        ud.set(drinkingFilterEnabled,      forKey: "drinkingFilterEnabled")
        ud.set(languageFilterEnabled,      forKey: "languageFilterEnabled")
        ud.set(relationshipGoalFilterEnabled, forKey: "relationshipGoalFilterEnabled")
    }

    // Load filters from UserDefaults
    static func loadFilters() -> Filters {
        let ud = UserDefaults.standard
        return Filters(
            minWeight:                    ud.double(forKey: "minWeight").nonZeroOr(100),
            maxWeight:                    ud.double(forKey: "maxWeight").nonZeroOr(300),
            minHeight:                    ud.double(forKey: "minHeight").nonZeroOr(50),
            maxHeight:                    ud.double(forKey: "maxHeight").nonZeroOr(84),
            gender:                       ud.string(forKey: "gender"),
            weightFilterEnabled:          ud.bool(forKey: "weightFilterEnabled"),
            heightFilterEnabled:          ud.bool(forKey: "heightFilterEnabled"),
            genderFilterEnabled:          ud.bool(forKey: "genderFilterEnabled"),
            locationFilterEnabled:        ud.bool(forKey: "locationFilterEnabled"),
            maxDistance:                  ud.double(forKey: "maxDistance").nonZeroOr(50),
            religion:                     ud.string(forKey: "religion"),
            ethnicity:                    ud.string(forKey: "ethnicity"),
            smoking:                      ud.string(forKey: "smoking"),
            drinking:                     ud.string(forKey: "drinking"),
            language:                     ud.string(forKey: "language"),
            relationshipGoal:             ud.string(forKey: "relationshipGoal"),
            religionFilterEnabled:        ud.bool(forKey: "religionFilterEnabled"),
            ethnicityFilterEnabled:       ud.bool(forKey: "ethnicityFilterEnabled"),
            smokingFilterEnabled:         ud.bool(forKey: "smokingFilterEnabled"),
            drinkingFilterEnabled:        ud.bool(forKey: "drinkingFilterEnabled"),
            languageFilterEnabled:        ud.bool(forKey: "languageFilterEnabled"),
            relationshipGoalFilterEnabled: ud.bool(forKey: "relationshipGoalFilterEnabled")
        )
    }
}


// FilterSheet UI - Added switches for each filter and set default to off
struct FilterSheet: View {
    @Binding var filters: Filters
    var applyFilters: () -> Void
    @State private var distance: Double = 50  // default value
    
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Weight Range")) {
                    Toggle("Enable Weight Filter", isOn: $filters.weightFilterEnabled)
                    if filters.weightFilterEnabled {
                        VStack {
                            Text("Min Weight: \(Int(filters.minWeight)) lbs")
                            Slider(value: $filters.minWeight, in: 50...300, step: 1)
                        }
                        VStack {
                            Text("Max Weight: \(Int(filters.maxWeight)) lbs")
                            Slider(value: $filters.maxWeight, in: 50...300, step: 1)
                        }
                    }
                }
                Section(header: Text("Height Range")) {
                    Toggle("Enable Height Filter", isOn: $filters.heightFilterEnabled)
                    if filters.heightFilterEnabled {
                        VStack {
                            Text("Min Height: \(Int(filters.minHeight)) inches")
                            Slider(value: $filters.minHeight, in: 50...84, step: 1)
                        }
                        VStack {
                            Text("Max Height: \(Int(filters.maxHeight)) inches")
                            Slider(value: $filters.maxHeight, in: 50...84, step: 1)
                        }
                    }
                }
                
                
                Section(header: Text("Gender")) {
                    Toggle("Enable Gender Filter", isOn: $filters.genderFilterEnabled)
                    if filters.genderFilterEnabled {
                        Picker("Gender", selection: $filters.gender) {
                            Text("Any").tag(nil as String?)
                            Text("Male").tag("Male" as String?)
                            Text("Female").tag("Female" as String?)
                            Text("Other").tag("Other" as String?)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("Distance Filter")) {
                    Toggle("Enable Distance Filter", isOn: $filters.locationFilterEnabled)
                    if filters.locationFilterEnabled {
                        VStack(alignment: .leading) {
                            Slider(value: $filters.maxDistance, in: 1...100, step: 1)
                            Text("\(Int(filters.maxDistance)) miles")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
                Section(header: Text("Religion")) {
                    Toggle("Enable Religion Filter", isOn: $filters.religionFilterEnabled)

                    if filters.religionFilterEnabled {
                        Picker("Religion", selection: $filters.religion) {
                            Text("Any").tag(nil as String?)
                            Text("Christian").tag("Christian" as String?)
                            Text("Muslim").tag("Muslim" as String?)
                            Text("Jewish").tag("Jewish" as String?)
                            Text("Atheist").tag("Atheist" as String?)
                        }
                    }
                }
                Section(header: Text("Relationship Goal")) {
                    Toggle("Enable Goal Filter", isOn: $filters.relationshipGoalFilterEnabled)

                    if filters.relationshipGoalFilterEnabled {
                        Picker("Goal", selection: $filters.relationshipGoal) {
                            Text("Any").tag(nil as String?)
                            Text("Long-term relationship").tag("Long-term relationship" as String?)
                            Text("Short-term dating").tag("Short-term dating" as String?)
                            Text("Friends").tag("Friends" as String?)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("Ethnicity")) {
                    Toggle("Enable Ethnicity Filter", isOn: $filters.ethnicityFilterEnabled)

                    if filters.ethnicityFilterEnabled {
                        Picker("Ethnicity", selection: $filters.ethnicity) {
                            Text("Any").tag(nil as String?)
                            Text("White").tag("White" as String?)
                            Text("Black").tag("Black" as String?)
                            Text("Asian").tag("Asian" as String?)
                            Text("Hispanic / Latino").tag("Hispanic / Latino" as String?)
                            Text("Middle Eastern").tag("Middle Eastern" as String?)
                            Text("Native American").tag("Native American" as String?)
                            Text("Mixed").tag("Mixed" as String?)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("Smoking")) {
                    Toggle("Enable Smoking Filter", isOn: $filters.smokingFilterEnabled)

                    if filters.smokingFilterEnabled {
                        Picker("Smoking", selection: $filters.smoking) {
                            Text("Any").tag(nil as String?)
                            Text("Never").tag("Never" as String?)
                            Text("Sometimes").tag("Sometimes" as String?)
                            Text("Regularly").tag("Regularly" as String?)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("Drinking")) {
                    Toggle("Enable Drinking Filter", isOn: $filters.drinkingFilterEnabled)

                    if filters.drinkingFilterEnabled {
                        Picker("Drinking", selection: $filters.drinking) {
                            Text("Any").tag(nil as String?)
                            Text("Never").tag("Never" as String?)
                            Text("Socially").tag("Socially" as String?)
                            Text("Often").tag("Often" as String?)
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                
            }
            .navigationTitle("Filters")
            .navigationBarItems(trailing: Button("Apply") {
                applyFilters()
            })
        }
    }
}

// Helper so loadFilters defaults read cleanly
private extension Double {
    func nonZeroOr(_ default: Double) -> Double {
        self == 0 ? `default` : self
    }
}
