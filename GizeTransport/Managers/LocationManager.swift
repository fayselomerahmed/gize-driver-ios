//
//  LocationManager.swift
//  GizeTransport
//
//  Created by User on 11/15/22.
//
import SwiftUI
import Firebase
import FirebaseFirestoreSwift
import Combine
import FirebaseFirestore
import CoreLocation
import MapKit
import GeoFire

enum RegionType: String {
    case pickup
    case dropoff
}

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    static let shared = LocationManager()

    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var didEnterPickupRegion = false
    @Published var didEnterDropoffRegion = false
    var currentTripId: String?
    private let regionRadius: CLLocationDistance = 25
    private var pickupCoordinate: CLLocationCoordinate2D?
    private var dropoffCoordinate: CLLocationCoordinate2D?
    var trip: Trip?
    private var driversLocationRef: DatabaseReference?
    private var currentUserRef: DatabaseReference?
    private var geoFire: GeoFire?
    private var dbRef: DatabaseReference!
    private var currentCountryName: String?
    private var isUpdatingRemoteLocation = false
    private var lastRemoteLocationUpdate = Date.distantPast
    private let remoteLocationUpdateInterval: TimeInterval = 8
    @Published var heading: CLHeading?

    override init() {
        super.init()
        self.dbRef = Database.database().reference()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = 7
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    func createPickupRegionForTrip(_ trip: Trip) {
        pickupCoordinate = trip.pickupLocationCoordiantes
        checkDistanceFromMarkers()
    }

    func createDropoffRegionForTrip(_ trip: Trip) {
        dropoffCoordinate = trip.dropoffLocationCoordinates
        checkDistanceFromMarkers()
    }

    func checkDistanceFromMarkers() {
        guard let userLocation = userLocation else { return }

        if let pickupCoordinate = pickupCoordinate {
            let pickupLocation = CLLocation(latitude: pickupCoordinate.latitude, longitude: pickupCoordinate.longitude)
            didEnterPickupRegion = userLocation.distance(from: pickupLocation) < regionRadius
        }

        if let dropoffCoordinate = dropoffCoordinate {
            let dropoffLocation = CLLocation(latitude: dropoffCoordinate.latitude, longitude: dropoffCoordinate.longitude)
            didEnterDropoffRegion = userLocation.distance(from: dropoffLocation) < regionRadius
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        self.userLocation = newLocation
        checkDistanceFromMarkers()

        guard Auth.auth().currentUser != nil else { return }
        updateCurrentLocationInDatabase(newLocation)

        guard shouldSendRemoteLocationUpdate() else { return }
        isUpdatingRemoteLocation = true

        Task { [weak self] in
            guard let self = self else { return }
            await self.checkDriverActiveStatusAndUpdateLocation(coordinate: newLocation.coordinate)
            await MainActor.run {
                self.lastRemoteLocationUpdate = Date()
                self.isUpdatingRemoteLocation = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    private func checkDriverActiveStatusAndUpdateLocation(coordinate: CLLocationCoordinate2D) async {
        guard let driverUid = Auth.auth().currentUser?.uid else { return }

        let userRef = Firestore.firestore().collection("users").document(driverUid)
        do {
            let document = try await userRef.getDocument()
            if let isActive = document.data()?["isActive"] as? Bool, isActive {
                await reverseGeocodeAndUpdateLocation(driverUid: driverUid, coordinate: coordinate)
            } else {
                removeDriverLocation(driverUid: driverUid)
            }
        } catch {
            print("Error fetching isActive status: \(error.localizedDescription)")
        }
    }

    private func reverseGeocodeAndUpdateLocation(driverUid: String, coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let countryName = await withCheckedContinuation { continuation in
            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.country ?? "Unknown Country")
            }
        }
        await updateDriverLocation(driverUid: driverUid, coordinate: coordinate, countryName: standardizeCountryName(countryName))
    }

    private func standardizeCountryName(_ countryName: String) -> String {
        return countryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateDriverLocation(driverUid: String, coordinate: CLLocationCoordinate2D, countryName: String) async {
        if self.driversLocationRef == nil || self.driversLocationRef?.key != countryName {
            self.driversLocationRef = dbRef.child("DriversLocations").child(countryName)
            if let driversLocationRef = self.driversLocationRef {
                self.geoFire = GeoFire(firebaseRef: driversLocationRef)
            }
        }

        guard let geoFire = self.geoFire else {
            print("LocationManager: GeoFire is unavailable; skipping location update.")
            return
        }

        await withCheckedContinuation { continuation in
            geoFire.setLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), forKey: driverUid) { error in
                if let error = error {
                    print("Error setting location: \(error.localizedDescription)")
                } else {
                    print("Location updated successfully")
                }
                continuation.resume()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func removeDriverLocation(driverUid: String) {
        if self.driversLocationRef == nil {
            self.driversLocationRef = self.dbRef.child("DriversLocations")
            if let driversLocationRef = self.driversLocationRef {
                self.geoFire = GeoFire(firebaseRef: driversLocationRef)
            }
        }

        self.geoFire?.removeKey(driverUid) { error in
            if let error = error {
                print("LocationManager: Error removing location from GeoFire: \(error.localizedDescription)")
            } else {
                print("LocationManager: Location removed from GeoFire successfully")
            }
        }

        self.dbRef.child("DriversLocations").observeSingleEvent(of: .value) { snapshot in
            for case let child as DataSnapshot in snapshot.children {
                let ref = child.ref.child(driverUid)
                ref.removeValue { error, _ in
                    if let error = error {
                        print("LocationManager: Error removing value from Realtime Database: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func updateCurrentLocationInDatabase(_ location: CLLocation) {
        guard let driverUid = Auth.auth().currentUser?.uid else { return }
        currentUserRef = dbRef.child("users").child(driverUid)
        currentUserRef?.updateChildValues([
            "coordinates": [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
        ])
    }

    private func shouldSendRemoteLocationUpdate() -> Bool {
        guard !isUpdatingRemoteLocation else { return false }
        return Date().timeIntervalSince(lastRemoteLocationUpdate) >= remoteLocationUpdateInterval
    }
}
