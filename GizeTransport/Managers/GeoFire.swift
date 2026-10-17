//
//  GeoFire.swift
//  GizeDriver
//
//  Created by User on 4/24/24.
//

import SwiftUI
import Firebase
import GeoFire

// ViewModel to manage GeoFire operations
class GeoFireViewModel: ObservableObject {
    private var dbRef: DatabaseReference!
    private var pickupGeoFire: GeoFire?
    private var destinationGeoFire: GeoFire?

    init() {
        self.dbRef = Database.database().reference()
    }

    // Create GeoFire Pickup Location
    func createGeoFirePickupLocation(key: String, destination: CLLocationCoordinate2D) {
        let pickupRef = dbRef.child("TripPickupLocation")
        pickupGeoFire = GeoFire(firebaseRef: pickupRef)

        pickupGeoFire?.setLocation(CLLocation(latitude: destination.latitude, longitude: destination.longitude), forKey: key) { (error) in
            if let error = error {
                AppLogger.error("Could not save pickup location: \(error.localizedDescription)")
            }
        }
    }

    // Create GeoFire Destination Location
    func createGeoFireDestinationLocation(key: String, destination: CLLocationCoordinate2D) {
        let destinationRef = dbRef.child("TripDestinationLocation")
        destinationGeoFire = GeoFire(firebaseRef: destinationRef)

        destinationGeoFire?.setLocation(CLLocation(latitude: destination.latitude, longitude: destination.longitude), forKey: key) { (error) in
            if let error = error {
                AppLogger.error("Could not save destination location: \(error.localizedDescription)")
            }
        }
    }
}

//import SwiftUI
//import Firebase
//import GeoFire
//import CoreLocation
//
//class GeoFireManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private var dbRef: DatabaseReference!
//    private var geoFire: GeoFire?
//    private var locationManager: CLLocationManager
//    private var currentUserRef: DatabaseReference?
//    private var driversLocationRef: DatabaseReference?
//    
//    override init() {
//        self.dbRef = Database.database().reference()
//        self.locationManager = CLLocationManager()
//        super.init()
//        self.locationManager.delegate = self
//        self.locationManager.requestWhenInUseAuthorization()
//        self.locationManager.startUpdatingLocation()
//    }
//
//    // Function to update or delete driver location
//    func updateOrDeleteDriverLocation(withCoordinate coordinate: CLLocation) {
//        guard let driverUid = Auth.auth().currentUser?.uid else { return }
//        
//        // Reverse geocode to get the city name
//        let geocoder = CLGeocoder()
//        let location = CLLocation(latitude: coordinate.coordinate.latitude, longitude: coordinate.coordinate.longitude)
//        
//        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                print("Error getting city name: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let placemark = placemarks?.first, let cityName = placemark.locality else {
//                print("City name not found")
//                return
//            }
//            
//            // Check if the driver is active
//            let userRef = self.dbRef.child("users").child(driverUid)
//            userRef.observeSingleEvent(of: .value) { snapshot in
//                let isActive = snapshot.childSnapshot(forPath: "isActive").value as? Bool ?? false
//                
//                if isActive {
//                    // Create new driver location reference
//                    self.driversLocationRef = self.dbRef.child("DriversLocation").child(cityName)
//                    self.currentUserRef = self.driversLocationRef?.child(driverUid)
//                    
//                    self.geoFire = GeoFire(firebaseRef: self.driversLocationRef!)
//                    self.geoFire?.setLocation(location, forKey: driverUid) { error in
//                        if let error = error {
//                            print("Error setting location: \(error.localizedDescription)")
//                        } else {
//                            print("Location updated successfully")
//                        }
//                    }
//                } else {
//                    // Remove the driver location
//                    self.currentUserRef?.removeValue(completionBlock: { error, _ in
//                        if let error = error {
//                            print("Error removing value: \(error.localizedDescription)")
//                        } else {
//                            print("Location removed successfully")
//                        }
//                    })
//                }
//            }
//        }
//    }
//    
//    // CLLocationManagerDelegate method
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        guard let location = locations.last else { return }
//        updateOrDeleteDriverLocation(withCoordinate: location)
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
////        print("Failed to get location: \(error.localizedDescription)")
//    }
//}
//
