//
//  HomeViewModel.swift
//  GizeTransport
//
//  Created by User on 4/20/23.
//

import SwiftUI
import Firebase
import FirebaseFirestoreSwift
import Combine
import FirebaseFirestore
import FirebaseDatabase
import MapKit

class HomeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var distanceTraveled: Double = 0.0
    private var db = Firestore.firestore()
    private var lastLocation: CLLocation?
    private var isTrackingDistance = false
    @State var isShowTripCompleted = false
    @Published var drivers = [User]()
    @Published var passengers = [User]()
    var currentDriver: User?
    var selectedPassenger: Passenger?
    @State var isShowPopUp = true
    @Published var trip: Trip?
    @Published var preOrderTrip: Trip?
    @Published var preorderedTrip: Trip?
    @Published var trips: [Trip] = []
    @Published var mapState = MapViewState.noInput
    private let service = UserService.shared
    private var cancellables = Set<AnyCancellable>()
    var currentUser: User?
    var currentTripId: String?
    var routeToPickupLocation: MKPolyline?
    @Published var results = [MKLocalSearchCompletion]()
    @Published var searchResults: [MKLocalSearchCompletion] = []
    @Published var selectedUberLocation: UberLocation?
    @Published var pickUpTime: String?
    @Published var dropOffTime: String?
    @Published var currentLocation: CLLocation?
    @Published var passengerPhoneNumber: String?
    private let locationManager = CLLocationManager()
    private let userUpdateQueue = DispatchQueue(label: "com.gizetransport.userUpdateQueue")
    private var cancellationUpdateCompleted = false
    @Published var selectedReasons: Set<String> = []
    private var listener: ListenerRegistration?
    @Published var walletBalance: Double = 0.0
    @Published var reasonsForCancellation: [String] = [
        "Change of plans",
        "Long wait time",
        "Driver didn't show up",
        "Driver behaviour",
        "Found a better option",
        "Other"
    ]
    var userLocation: CLLocationCoordinate2D?
    @Published var driverCoordinate: CLLocationCoordinate2D?
    
    @Published var isActiveDriver: Bool = true {
         didSet {
             // Call the function to handle uploading/deleting driver coordinates
             updateActiveStatus(isActiveDriver)
         }
     }
    private let searchCompleter = MKLocalSearchCompleter()
    var queryFragment: String = "" {
        didSet {
            searchCompleter.queryFragment = queryFragment
        }
    }

    func clearSearchResults() {
        results.removeAll()
    }

    func updateDestination(location: String) {
        self.queryFragment = location
    }

    func fetchPassengerPhoneNumber(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            if let document = document, document.exists {
                self.passengerPhoneNumber = document.data()?["phonenumber"] as? String
            } else {
                print("Document does not exist")
            }
        }
    }

    func reset() {
        self.mapState = .noInput
        self.selectedUberLocation = nil
        self.trip = nil
        self.isTrackingDistance = false
        self.lastLocation = nil
    }

    override init() {
        super.init()
        observeTripStateChanges()
        observeWalletBalance()
        listenForPreorders()
        fetchUser()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        searchCompleter.delegate = self
        searchCompleter.queryFragment = queryFragment
    }

    // MARK: - HELPERS
    var tripCancelledMessage: String {
        guard let user = currentUser, let trip = trip else { return "" }
        if user.accountType == .passenger {
            if trip.state == .driverCancelled {
                return "Your Driver Cancelled this Trip. Press Ok to Continue"
            } else if trip.state == .passengerCancelled {
                return "Your Trip Has Been Cancelled"
            }
        } else {
            if trip.state == .passengerCancelled {
                return "Your Trip Has Been Cancelled"
            } else if trip.state == .driverCancelled {
                return "The Trip Has Been Cancelled By The Driver"
            }
        }
        return ""
    }
    func fetchTotalDistanceTraveled() {
        guard let uid = currentUser?.uid else {
            print("No user ID found.")
            return
        }

        db.collection("trips")
            .whereField("driverUid", isEqualTo: uid)
            .whereField("state", isEqualTo: "tripCompleted")  // Ensure the state matches how it's stored
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error getting documents: \(error)")
                } else if let documents = querySnapshot?.documents {
                    var totalDistance = 0.0
                    for document in documents {
                        let data = document.data()
                        if let distance = data["distanceTraveled"] as? Double {
                            totalDistance += distance
                        } else if let distanceInt = data["distanceTraveled"] as? Int {
                            totalDistance += Double(distanceInt)
                        } else {
                            print("Warning: distanceTraveled field missing or of unexpected type in document \(document.documentID)")
                        }
                    }
                    DispatchQueue.main.async {
                        self.distanceTraveled = totalDistance
                        print("Total distance traveled: \(self.distanceTraveled) meters")
                    }
                } else {
                    print("No documents found.")
                }
            }
    }
    func observeTripStateChanges() {
        guard let currentUser = currentUser else { return }

        let tripRef = Firestore.firestore().collection("trips")

        // Listen for changes where the current user is either the driver or the passenger
        tripRef.whereField("driverUid", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let self = self else { return }
                guard let snapshot = snapshot else {
                    print("Error fetching trip updates: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                for diff in snapshot.documentChanges {
                    if diff.type == .modified {
                        self.handleTripStateChange(document: diff.document)
                    }
                }
            }

        tripRef.whereField("passengerUid", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] (snapshot, error) in
                guard let self = self else { return }
                guard let snapshot = snapshot else {
                    print("Error fetching trip updates: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                for diff in snapshot.documentChanges {
                    if diff.type == .modified {
                        self.handleTripStateChange(document: diff.document)
                    }
                }
            }
    }
    func handleTripStateChange(document: DocumentSnapshot) {
        guard let trip = try? document.data(as: Trip.self) else { return }

        // Check if the state has changed
        if let oldTrip = self.trip, oldTrip.state == trip.state {
            // State hasn't changed, do nothing
            return
        }

        // Update the local trip object
        self.trip = trip

        // Call sendFCMMessageForTripStateChange based on the new state
        sendFCMMessageForTripStateChange(state: trip.state)
    }

    private func applyObservedTrip(_ trip: Trip, shouldUpdateRouteToPickup: Bool) {
        if trip.state.isTerminalForDriverSession {
            if self.trip?.id == trip.id {
                self.trip = trip
                stopTrackingDistance()
            }
            AppLogger.info("Ignoring inactive trip state: \(trip.state)")
            return
        }

        self.trip = trip
        AppLogger.info("Updated trip state is \(trip.state)")

        guard shouldUpdateRouteToPickup, trip.state.shouldRouteDriverToPickup else { return }
        getDestinationRouteForAppleMaps(from: trip.driverLocation.toCoordinate(),
                                        to: trip.pickupLocation.toCoordinate()) { route, travelTime, distance in
            self.routeToPickupLocation = route
            self.trip?.travelTimeToPassenger = Int(travelTime / 60)
            self.trip?.distanceToPassenger = distance
        }
    }

    func observeWalletBalance() {
           guard let uid = Auth.auth().currentUser?.uid else {
               print("No user ID found.")
               return
           }
           
           let ref = Database.database().reference().child("Wallet").child(uid).child("amount")
           
           ref.observe(.value) { snapshot in
               if let value = snapshot.value as? Double {
                   DispatchQueue.main.async {
                       self.walletBalance = value
                   }
               } else {
                   print("Wallet balance not found.")
               }
           }
       }
    func listenForPreorders() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated.")
            return
        }

        listener = Firestore.firestore().collection("preorder")
            .whereField("driverUid", isEqualTo: uid)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error fetching user trips: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    print("No documents found.")
                    return
                }

                // Decode and update the trips array
                self.trips = documents.compactMap { document -> Trip? in
                    do {
                        let tripData = try document.data(as: Trip.self)
                        return tripData
                    } catch {
                        print("Error decoding trip data: \(error.localizedDescription)")
                        return nil
                    }
                }
            }
    }
    func incrementDriverCancellationCount() {
        guard let user = currentUser, user.accountType == .driver else { return }
        let userRef = Firestore.firestore().collection("users").document(user.uid)
        
        userRef.updateData(["cancellationCount": FieldValue.increment(Int64(1))]) { [weak self] error in
            if let error = error {
                print("Error updating cancellation count: \(error.localizedDescription)")
            } else {
                print("Successfully incremented cancellation count")
                self?.userUpdateQueue.async {
                    DispatchQueue.main.async {
                        if let currentCount = self?.currentUser?.cancellationCount {
                            self?.currentUser?.cancellationCount = currentCount + 1
                        } else {
                            self?.currentUser?.cancellationCount = 1
                        }
                        self?.cancellationUpdateCompleted = true
                    }
                }
            }
        }
    }

    func runIncrementCancellationLoop() {
        var loopCount = 0
        while loopCount < 1 {
            incrementDriverCancellationCount()
            loopCount += 1
        }
        print("Cancellation loop completed.")
    }


    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        userLocation = location.coordinate

        guard shouldUpdateCurrentTripLocation else { return }

        if isTrackingDistance {
            if let lastLocation = lastLocation {
                let distance = location.distance(from: lastLocation)
                distanceTraveled += distance
            } else {
                lastLocation = location
            }
        }

        updateLocationInDatabase(location)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")

        // Attempt to recover from the error
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            // Ignore temporary errors
            return
        } else {
            // Restart location updates
            manager.stopUpdatingLocation()
            manager.startUpdatingLocation()
        }
    }

    private func updateLocationInDatabase(_ location: CLLocation) {
        guard let tripId = trip?.tripId, shouldUpdateCurrentTripLocation else { return }

        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let locationData = ["currentLat": latitude, "currentLng": longitude]
        let ref = Database.database().reference().child("Trips").child(tripId)

        ref.updateChildValues(locationData) { error, _ in
            if let error = error {
                AppLogger.error("Error updating trip location: \(error.localizedDescription)")
            }
        }
    }

    private var shouldUpdateCurrentTripLocation: Bool {
        guard let trip = trip, trip.tripId != nil else { return false }
        return trip.state.shouldUpdateDriverLocation
    }

    func viewForState(_ state: MapViewState, user: User) -> some View {
        switch state {
        case .locationSelected:
            return AnyView(EmptyView()) // Update with your view

        case .tripRequested:
            if let trip = self.trip {
                return AnyView(AcceptTripView(trip: trip))
            }

        case .tripAccepted, .polylineAdded:
            if state == .tripAccepted || trip?.tripType == .now {
                if let trip = self.trip {
                    if trip.tripType == .now {
                        return AnyView(PickupPassengerView(trip: trip))
                    } else {
                        return AnyView(PreorderSuccessfulView(showingPopup: $isShowPopUp))
                    }
                }
                else if state == .tripAccepted || trip?.tripType == .preorder {
                    return AnyView(PreorderSuccessfulView(showingPopup: $isShowPopUp))
                }
            }

        case .tripCancelledByPassenger, .tripCancelledByDriver:
            return AnyView(TripCancelledView())

        case .tripArrived:
            if let trip = self.trip {
                return AnyView(ArrivalAtPassengerView(trip: trip))
            }

        case .noTrip:
            if let trip = self.trip {
                return AnyView(TripDetailsView(trip: trip))
            }

        case .tripStarted:
            if let trip = self.trip {
                return AnyView(TripStartedView(trip: trip))
            }

        case .tripCompleted:
            if let trip = self.trip {
                return AnyView(TripCompletedView(trip: trip, isPresented: $isShowTripCompleted))
            }
        case .preordered:
            return AnyView(PreorderSuccessfulView(showingPopup: $isShowPopUp))

        default:
            break
        }
        return AnyView(Text(""))
    }

    func fetchUser() {
        service.$user
            .sink { [weak self] user in
                guard let self = self else { return }
                guard let user = user else {
                    print("user is nil ")
                    return
                }

                self.currentUser = user

                guard user.accountType == .driver else {
                    print("not a driver account try again")
                    return
                }

                self.addTripObserverForDriver()
                self.addPreorderObserverForDriver()
                self.addTripObserverForPassenger()
                self.fetchDrivers()
                self.reset()
            }
            .store(in: &cancellables)
    }

    func emergencyCall() {
        print("Emergency button tapped")
        if let url = URL(string: "tel://911"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    private func updateTripState(state: TripState) {
        guard let trip = trip else { return }

        var data: [String: Any] = ["state": state.rawValue]

        if state == .accepted {
            data["travelTimeToPassenger"] = trip.travelTimeToPassenger
        } else if state == .noTrip {
            reset()
        }

        let firestoreTripRef = Firestore.firestore().collection("trips").document(trip.id)
        let firestorePreorderRef = Firestore.firestore().collection("preorder").document(trip.id)

        let targetRef = trip.tripType == .now ? firestoreTripRef : firestorePreorderRef

        targetRef.updateData(data) { error in
            if let error = error {
                print("ERROR: Failed to update trip in Firestore: \(error.localizedDescription)")
            } else {
                print("DEBUG: Trip state updated to \(state)")
                // Send FCM message after updating the trip state
                self.sendFCMMessageForTripStateChange(state: state)
            }
        }
    }
    private func sendFCMMessageForTripStateChange(state: TripState) {
        guard let trip = trip else {
            print("Trip is nil, cannot send FCM message")
            return
        }
        
        switch state {
        case .accepted:
            let driverName = trip.driverName
            FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Trip has been accepted!", body: "Driver \(driverName) is on the way to pick you up.")
        case .arrived:
            let driverName = trip.driverName
            FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Your Driver has Arrived!", body: "Driver \(driverName) is at your location.")
        case .starttrip:
            let driverName = trip.driverName
            FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Trip Started!", body: "Driver \(driverName) has started the trip.")
        case .tripCompleted:
            let tripCostString = String(format: "%.2f", trip.tripCost)
            FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Trip completed!", body: "Your fare is \(tripCostString)")
        case .passengerCancelled:
            let passengerName = trip.passengerName
            FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Your trip has been cancelled by the passenger", body: "Passenger \(passengerName) cancelled the trip.")
        case .driverCancelled:
            let driverName = trip.driverName
            FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Your trip has been cancelled by the driver", body: "Driver \(driverName) cancelled the trip.")
        default:
            break
        }
    }



    private func sendFCMMessageTripAccepted() {
        guard let passengerUid = trip?.passengerUid else { return }
        fetchUserFCMToken(userUID: passengerUid) { token in
            guard let token = token else { return }
            let notificationData: [String: Any] = [
                "title": "Trip Accepted",
                "body": "Your trip request has been accepted.",
                "tripId": self.trip?.tripId ?? ""
            ]
            self.sendFCMMessageForMessaging(toToken: token, data: notificationData)
        }
    }

    private func sendFCMMessageDriverArrived() {
        guard let passengerUid = trip?.passengerUid else { return }
        fetchUserFCMToken(userUID: passengerUid) { token in
            guard let token = token else { return }
            let notificationData: [String: Any] = [
                "title": "Driver Arrived",
                "body": "Your driver has arrived at the pickup location.",
                "tripId": self.trip?.tripId ?? ""
            ]
            self.sendFCMMessageForMessaging(toToken: token, data: notificationData)
        }
    }
    private func sendFCMMessageForStartTrip() {
        guard let passengerUid = trip?.passengerUid else { return }
        fetchUserFCMToken(userUID: passengerUid) { token in
            guard let token = token else { return }
            let notificationData: [String: Any] = [
                "title": "Trip Started",
                "body": "Your trip has started.",
                "tripId": self.trip?.tripId ?? ""
            ]
            self.sendFCMMessageForMessaging(toToken: token, data: notificationData)
        }
    }
    private func sendFCMMessageTripCompleted() {
        guard let passengerUid = trip?.passengerUid else { return }
        fetchUserFCMToken(userUID: passengerUid) { token in
            guard let token = token else { return }
            let notificationData: [String: Any] = [
                "title": "Trip Completed",
                "body": "Your trip has been completed.",
                "tripId": self.trip?.tripId ?? ""
            ]
            self.sendFCMMessageForMessaging(toToken: token, data: notificationData)
        }
    }
    private func sendFCMMessageTripCancelledByPassenger() {
        guard let driverUid = trip?.driverUid else { return }
        fetchUserFCMToken(userUID: driverUid) { token in
            guard let token = token else { return }
            let notificationData: [String: Any] = [
                "title": "Trip Cancelled",
                "body": "The passenger has cancelled the trip.",
                "tripId": self.trip?.tripId ?? ""
            ]
            self.sendFCMMessageForMessaging(toToken: token, data: notificationData)
        }
    }
    private func sendFCMMessageTripCancelledByDriver() {
        guard let passengerUid = trip?.passengerUid else { return }
        fetchUserFCMToken(userUID: passengerUid) { token in
            guard let token = token else { return }
            let notificationData: [String: Any] = [
                "title": "Trip Cancelled",
                "body": "The driver has cancelled the trip.",
                "tripId": self.trip?.tripId ?? ""
            ]
            self.sendFCMMessageForMessaging(toToken: token, data: notificationData)
        }
    }
    func fetchUserFCMToken(userUID: String, completion: @escaping (String?) -> Void) {
        let usersCollection = Firestore.firestore().collection("users")
        usersCollection.document(userUID).getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error)")
                completion(nil)
                return
            }

            if let document = document, document.exists {
                let fcmToken = document.data()?["fcmToken"] as? String
                completion(fcmToken)
            } else {
                completion(nil)
            }
        }
    }


    func deletePreorderTrip() {
        guard let trip = trip else { return }
        Firestore.firestore().collection("preorder").document(trip.id).delete { _ in
            self.trip = nil
        }
    }

    func deleteTrip() {
        guard let trip = trip else { return }
        Firestore.firestore().collection("trips").document(trip.id).delete { _ in
            self.trip = nil
        }
    }
}

// MARK: - Passenger API

extension HomeViewModel {
    func selectLocation(_ location: UberLocation) {
        selectedUberLocation = location
    }

    func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ride Request Sent"
        content.body = "Please Wait until a driver is assigned to you"
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    func updateLocation(withCoordinate coordinate: CLLocation) {
        guard let trip = self.trip else { return }
        guard let tripUid = trip.tripId else { return }

        let updateTrip: [String: Any] = [
            "currentLat": coordinate.coordinate.latitude,
            "currentLng": coordinate.coordinate.longitude
        ]

        let ref = Database.database().reference()
        let tripRef = ref.child("Trips").child(tripUid)

        tripRef.updateChildValues(updateTrip) { error, _ in
            if let error = error {
                print("Error updating trip: \(error.localizedDescription)")
            } else {
                print("Trip location successfully updated")
            }
        }
    }

    func sendFCMMessageStartTrip() {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        guard let driverToken = ProcessInfo.processInfo.environment["FCM_TEST_DEVICE_TOKEN"], !driverToken.isEmpty else {
            AppLogger.warning("Configure a test device token locally; production notifications require a trusted backend.")
            return
        }

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "Driver Arrived",
            "body": "Your driver has arrived",
            "DriverKey": "demo-driver-id",
            "RiderKey": trip.passengerUid,
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }

    func sendFCMMessageDone() {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        let driverToken = trip?.fcmToken

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "DriverCompleteTrip",
            "body": "Trip Completed",
            "TripKey": trip.tripId as Any,
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }

    func deleteNestedDataForUser(uid: String) {
        let databaseRef = Database.database().reference()
        let userTripDestinationLocationRef = databaseRef.child("TripDestinationLocation").child(uid)
        userTripDestinationLocationRef.removeValue { error, _ in
            if let error = error {
                print("Error deleting data: \(error.localizedDescription)")
            } else {
                print("Nested data deleted successfully")
            }
        }
    }

    func deleteNestedDataForUserDestination(uid: String) {
        let databaseRef = Database.database().reference()
        let userTripDestinationLocationRef = databaseRef.child("TripPickupLocation").child(uid)
        userTripDestinationLocationRef.removeValue { error, _ in
            if let error = error {
                print("Error deleting data: \(error.localizedDescription)")
            } else {
                print("Nested data deleted successfully")
            }
        }
    }

    func sendFCMMessageArrived() {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        let driverToken = trip?.fcmToken

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "Driver Arrived",
            "body": "Your driver has arrived",
            "DriverKey": trip.driverUid,
            "RiderKey": trip.passengerUid,
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }
    private func sendFCMMessageForMessaging(toToken token: String, data: [String: Any]) {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint

        let payload: [String: Any] = [
            "to": token,
            "notification": [
                "title": data["title"] as? String ?? "",
                "body": data["body"] as? String ?? ""
            ],
            "data": data
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending FCM message: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: HTTP Response Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("FCM message sent successfully")
                } else {
                    print("Failed to send FCM message.")
                }
            }
        }
        task.resume()
    }


    func sendFCMMessage() {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        let driverToken = trip?.fcmToken

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "Accept",
            "body": "Testing has accepted your request",
            "DriverKey": currentUser?.uid,
            "TripKey": trip.tripId as Any,
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }

    func addTripObserverForPassenger() {
        guard let currentUser = currentUser, currentUser.accountType == .passenger else { return }

        Firestore.firestore().collection("trips")
            .whereField("passengerUid", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                guard let change = snapshot?.documentChanges.first,
                      change.type == .added || change.type == .modified else { return }

                guard let trip = try? change.document.data(as: Trip.self) else { return }
                self.applyObservedTrip(trip, shouldUpdateRouteToPickup: false)
            }
    }

    func fetchDrivers() {
        Firestore.firestore().collection("users")
            .whereField("accountType", isEqualTo: AccountType.passenger.rawValue)
            .getDocuments { [weak self] snapshot, _ in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else { return }
                let passengers = documents.compactMap { try? $0.data(as: User.self) }
                self.passengers = passengers
            }
    }

    private func realtimeTripPayload(for trip: Trip, driver: User, tripType: String) -> [String: Any] {
        let driverNames = driver.fullname.split(separator: " ", maxSplits: 1).map(String.init)
        let passengerNames = trip.passengerName.split(separator: " ", maxSplits: 1).map(String.init)
        let distanceKilometers = max(0, trip.distanceToPassenger)
        let travelMinutes = max(0, trip.travelTimeToPassenger)
        let timestamp = ISO8601DateFormatter().string(from: Date())

        return [
            "cancel": false,
            "currentLat": driver.coordinates.latitude,
            "currentLng": driver.coordinates.longitude,
            "destination": "\(trip.dropoffLocation.latitude),\(trip.dropoffLocation.longitude)",
            "destinationString": trip.dropofflocationName,
            "distancePickup": String(format: "%.1f km", distanceKilometers),
            "distanceText": String(format: "%.1f km", distanceKilometers),
            "distanceValue": Int((distanceKilometers * 1_000).rounded()),
            "done": false,
            "driver": driver.uid,
            "driverInfoModel": [
                "firstname": driverNames.first ?? driver.fullname,
                "lastname": driverNames.dropFirst().first ?? "",
                "rating": driver.Rating ?? 0,
                "status": driver.status
            ],
            "durationPickup": "\(travelMinutes) min",
            "durationText": "\(travelMinutes) min",
            "durationValue": travelMinutes,
            "origin": "\(trip.pickupLocation.latitude),\(trip.pickupLocation.longitude)",
            "rider": trip.passengerUid,
            "riderModel": [
                "firstName": passengerNames.first ?? trip.passengerName,
                "lastName": passengerNames.dropFirst().first ?? ""
            ],
            "timeText": timestamp,
            "totalFee": trip.tripCost,
            "tripType": tripType
        ]
    }

    func AcceptTripForRealTime() {
        guard let currentUser = currentUser, let tripT = trip, let tripId = tripT.tripId else {
            print("DEBUG: One or more required properties are nil.")
            return
        }

        let tripData = realtimeTripPayload(for: tripT, driver: currentUser, tripType: "now")

        let ref = Database.database().reference().child("Trips")
        ref.child(tripId).setValue(tripData) { error, _ in
            if let error = error {
                AppLogger.error("Ride record upload failed: \(error.localizedDescription)")
            }
        }
    }
    func markTripAsDone(tripId: String) {
           let ref = Database.database().reference().child("Trips").child(tripId)
           
           let updateData = ["done": true]

           ref.updateChildValues(updateData) { error, _ in
               if let error = error {
                   print("Error updating trip to done: \(error.localizedDescription)")
               } else {
                   print("DEBUG: Successfully marked trip as done")
               }
           }
       }

    func startTrip(trip: Trip) {
        // Update the local state
        self.trip = trip
        self.trip?.state = .starttrip
        
        // Log the starting of the trip
        AppLogger.info("Starting a trip.")
        
        // Update the trip status in Firestore
        let ref = Firestore.firestore().collection("preorder").document(trip.id)
        ref.updateData(["state": TripState.starttrip.rawValue]) { error in
            if let error = error {
                print("Error updating trip status: \(error.localizedDescription)")
            } else {
                print("Trip status updated to started")
                // Transfer the trip from preorder collection to trips collection
                self.transferTripToTripsCollection(trip: trip)
            }
        }
    }

    private func transferTripToTripsCollection(trip: Trip) {
        let firestore = Firestore.firestore()
        let tripsRef = firestore.collection("trips").document(trip.id)
        
        // Update the trip state to tripCompleted
        var updatedTrip = trip
        updatedTrip.state = .starttrip
        updatedTrip.tripType = .now
        // Add the trip to the trips collection
        do {
            try tripsRef.setData(from: updatedTrip) { error in
                if let error = error {
                    print("Error uploading trip to trips collection: \(error.localizedDescription)")
                } else {
                    print("Trip successfully uploaded to trips collection")
                    // Delete the trip from the preorder collection after starting it
                    self.deleteTrip(trip: trip)
                }
            }
        } catch {
            print("Error encoding trip data: \(error.localizedDescription)")
        }
    }

    func deleteTrip(trip: Trip) {
        let ref = Firestore.firestore().collection("preorder").document(trip.id)
        ref.delete { error in
            if let error = error {
                print("Error deleting trip: \(error.localizedDescription)")
            } else {
                print("Trip successfully deleted")
            }
        }
    }
    func sendFCMNotificationForPreorder() {
        guard let currentUser = currentUser, let tripT = trip, let tripId = tripT.tripId else {
            print("DEBUG: One or more required properties are nil.")
            return
        }
        fetchPassengerFCMToken(passengerUID: selectedPassenger?.id ?? "") { token in
            self.sendFCMMessagePreorder(with: token ?? "" )
        }

        let tripData = realtimeTripPayload(for: tripT, driver: currentUser, tripType: "pre_order")

        let ref = Database.database().reference().child("Trips")
        ref.child(tripId).setValue(tripData) { error, _ in
            if let error = error {
                AppLogger.error("Preorder record upload failed: \(error.localizedDescription)")
            }
        }
    }
    func sendFCMNotificationForManual() {
        guard let currentUser = currentUser, let tripT = trip, let tripId = tripT.tripId else {
            print("DEBUG: One or more required properties are nil.")
            return
        }

        let tripData = realtimeTripPayload(for: tripT, driver: currentUser, tripType: "manual")

        let ref = Database.database().reference().child("Trips")
        ref.child(tripId).setValue(tripData) { error, _ in
            if let error = error {
                AppLogger.error("Manual ride record upload failed: \(error.localizedDescription)")
            }
        }
    }

    func fetchPassengerByPhoneNumber(phoneNumber: String, completion: @escaping (User?) -> Void) {
        Firestore.firestore().collection("users").whereField("phonenumber", isEqualTo: phoneNumber).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching documents: \(error)")
                return
            }
            guard let document = snapshot?.documents.first else {
                print("No document found")
                return
            }
            do {
                let decoder = Firestore.Decoder()
                let user = try decoder.decode(User.self, from: document.data())
                completion(user)
            } catch {
                print("Error decoding user: \(error)")
                completion(nil)
            }
        }
    }
    func sendFCMMessage(with Token: String) {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        let driverToken = Token

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "RequestDriver",
            "body": "This message represents a request driver action",
            "RiderKey": trip.passengerUid,
            "PickupLocationString": trip.pickupLocationName,
            "PickupLocation": "\(trip.pickupLocation.latitude),\(trip.pickupLocation.longitude)",
            "DestinationLocationString": trip.dropofflocationName,
            "DestinationLocation": "\(trip.dropoffLocation.latitude),\(trip.dropoffLocation.longitude)",
            "DistanceText": "\(trip.distanceToPassenger)",
            "DistanceValue": "\(trip.travelTimeToPassenger)",
            "DurationText": "\(trip.travelTimeToPassenger)",
            "TimeValue": "600",
            "TotalFee": "\(trip.tripCost.rounded())",
            "timeText": "2023-10-28 12:00:00",
            "tripType": "now",
            "FaysTripKey": trip.id,
            "platform": "IOS"
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }

        task.resume()
    }
    func sendFCMMessagePreorder(with Token: String) {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        let driverToken = Token

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "ManualTrip",
            "body": "Preorder Trip Activated",
            "TripKey": trip.tripId as Any,
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }
    func sendFCMMessagePreorderTrip(with Token: String) {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint
        let driverToken = Token

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "ManualTrip",
            "body": "Pre order Trip Activated",
            "TripKey": trip.tripId as Any,
        ]

        let payload: [String: Any] = [
            "to": driverToken,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }


       func fetchPassengerFCMToken(passengerUID: String, completion: @escaping (String?) -> Void) {
           let COLLECTION_USERS = Firestore.firestore().collection("users")
           COLLECTION_USERS.document(passengerUID).getDocument { document, error in
               if let error = error {
                   print("Error fetching passenger document: \(error)")
                   completion(nil)
                   return
               }
               
               if let document = document, document.exists {
                   let fcmToken = document.data()?["fcmToken"] as? String
                   completion(fcmToken)
               } else {
                   completion(nil)
               }
           }
       }

    func startManualTrip(withPassengerUid passengerUid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(passengerUid).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            guard let document = document, document.exists, error == nil else {
                print("Error fetching passenger data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            guard let passenger = try? document.data(as: User.self) else {
                print("Error decoding passenger data")
                return
            }

            guard let driver = self.currentUser, let driverLocation = self.currentUser?.coordinates else {
                print("Error: Driver details or location not available")
                return
            }

            let trip = Trip(
                tripId: UUID().uuidString,
                passengerUid: passenger.uid,
                driverUid: driver.uid,
                passengerName: passenger.fullname,
                driverName: driver.fullname,
                passengerLocation: passenger.coordinates,
                driverLocation: driverLocation,
                pickupLocationName: "Driver's Current Location",
                dropofflocationName: "Enter drop-off location",
                pickupLocationAddress: "Driver's Location Address",
                pickupLocation: GeoPoint(
                    latitude: driverLocation.latitude,
                    longitude: driverLocation.longitude
                ),
                dropoffLocation: GeoPoint(
                    latitude: 0,
                    longitude: 0
                ),
                tripCost: self.computeRidePrice(forType: .Economy),
                distanceToPassenger: 10,
                travelTimeToPassenger: 15,
                state: .requested,
                tripType: .now,
                tripDate: Date()
            )

            do {
                let encodedTrip = try Firestore.Encoder().encode(trip)
                Firestore.firestore().collection("trips").addDocument(data: encodedTrip) { error in
                    if let error = error {
                        print("Error uploading trip to Firestore: \(error.localizedDescription)")
                    } else {
                        print("Trip successfully uploaded to Firestore")

                        // Check if the platform is Android before sending FCM
                        if passenger.platform == "Android" {
                            self.sendFCMMessageManualTrip(with: passenger.fcmToken ?? "")
                            self.sendFCMNotificationForManual()
                        }
                    }
                }
            } catch {
                print("Failed to encode trip: \(error)")
            }
        }
    }

    func sendFCMMessageManualTrip(with token: String) {
        guard let serverKey = AppConfig.legacyFCMServerKey else {
            AppLogger.warning("Legacy FCM server key is not configured. Route notifications through the backend before App Store release.")
            return
        }
        let endpoint = AppConfig.legacyFCMEndpoint

        guard let trip = trip else {
            print("Trip is nil, cannot proceed")
            return
        }

        let notificationData: [String: Any] = [
            "title": "ManualTrip",
            "body": "Manual Trip Activated",
            "TripKey": trip.tripId as Any,
        ]

        let payload: [String: Any] = [
            "to": token,
            "data": notificationData
        ]

        guard let url = URL(string: endpoint),
              let jsonPayload = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=\(serverKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonPayload

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending FCM message: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    if let responseData = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let success = responseData["success"] as? Int, success == 1 {
                        AppLogger.info("Successfully sent FCM message.")
                    } else {
                        AppLogger.warning("Failed to send FCM message.")
                    }
                } catch {
                    print("Error parsing response JSON: \(error)")
                }
            } else {
                print("HTTP Error: Status code is not 200")
            }
        }
        task.resume()
    }


    func requestTrip() {
        guard let passenger = selectedPassenger.self else {
            print("DEBUG: No drivers available")
            return
        }
        
        guard let currentUser = currentUser else {
            print("DEBUG: Current user not found")
            return
        }
        guard let dropOffLocation = selectedUberLocation else {
            print("DEBUG: Drop-off location not selected")
            return
        }

        let dropoffGeopoint = GeoPoint(
            latitude: dropOffLocation.coordinate.latitude,
            longitude: dropOffLocation.coordinate.longitude
        )

        let userLocation = CLLocation(
            latitude: currentUser.coordinates.latitude,
            longitude: currentUser.coordinates.longitude
        )

        getPlacemark(forLocation: userLocation) { [weak self] placemark, error in
            guard let self = self, let placemark = placemark else {
                print("DEBUG: Error getting placemark: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let tripCost = self.computeRidePrice(forType: .Economy)

            let trip = Trip(
                passengerUid: passenger.id ?? "",
                driverUid: currentUser.uid,
                passengerName: passenger.fullname,
                driverName: currentUser.fullname,
                passengerLocation: passenger.coordinates,
                driverLocation: currentUser.coordinates,
                pickupLocationName: placemark.name ?? "Current Location",
                dropofflocationName: dropOffLocation.title,
                pickupLocationAddress: self.addressFromPlacemark(placemark),
                pickupLocation: currentUser.coordinates,
                dropoffLocation: dropoffGeopoint,
                tripCost: tripCost,
                distanceToPassenger: 0,
                travelTimeToPassenger: 0,
                state: .starttrip,
                tripType: .now,
                tripDate: Date()
            )

            do {
                let encodedTrip = try Firestore.Encoder().encode(trip)
                Firestore.firestore().collection("trips").addDocument(data: encodedTrip) { error in
                    if let error = error {
                        print("Error uploading trip to Firestore: \(error.localizedDescription)")
                    } else {
                        print("DEBUG: Trip uploaded to Firestore successfully")
                    }
                }
            } catch {
                print("DEBUG: Failed to encode trip: \(error)")
            }
        }
    }

    func cancelTripAsPassenger() {
        updateTripState(state: .passengerCancelled)
    }
}

// MARK: - Driver API

extension HomeViewModel {
    func updateActiveStatus(_ isActive: Bool) {
        guard let driverUid = Auth.auth().currentUser?.uid else { return }

        let userRef = Firestore.firestore().collection("users").document(driverUid)
        
        userRef.updateData(["isActive": isActive]) { error in
            if let error = error {
                print("Error updating isActive status: \(error.localizedDescription)")
            } else {
                print("Successfully updated isActive status.")
                if isActive {
                    LocationManager.shared.startUpdatingLocation()
                } else {
                    LocationManager.shared.stopUpdatingLocation()
                    LocationManager.shared.removeDriverLocation(driverUid: driverUid)
                }
            }
        }
    }

    func deleteDriverLocation() {
        guard let driverUid = Auth.auth().currentUser?.uid else {
            print("Error: User is not authenticated.")
            return
        }

        let db = Firestore.firestore()
        db.collection("drivers-location").document(driverUid).delete() { error in
            if let error = error {
                print("Error removing driver's location: \(error.localizedDescription)")
            } else {
                print("Driver's location successfully deleted.")
            }
        }
    }

    func updateDriverLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated.")
            return
        }

        guard self.isActiveDriver else {
            Firestore.firestore().collection("driver_coordinates").document(uid).delete { error in
                if let error = error {
                    print("Error deleting driver_coordinates: \(error.localizedDescription)")
                } else {
                    print("Firestore deleted driver_coordinates.")
                }
            }
            return
        }

        let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)

        Firestore.firestore().collection("driver_coordinates").document(uid).setData([
            "coordinates": geoPoint
        ], merge: true) { error in
            if let error = error {
                print("Error updating Firestore with location for driver_coordinates: \(error.localizedDescription)")
            } else {
                print("Firestore updated with new location for driver_coordinates.")
            }
        }

        Firestore.firestore().collection("users").document(uid).setData([
            "coordinates": geoPoint
        ], merge: true) { error in
            if let error = error {
                print("Error updating Firestore with location for user: \(error.localizedDescription)")
            } else {
                print("Firestore updated with new location for user.")
            }
        }
    }

    func handlePreorderedTripRequest(_ trip: Trip, documentID: String) {
        var updatedTrip = trip
        updatedTrip.state = .accepted
        updatedTrip.tripType = .preorder
        guard let encodedTrip = try? Firestore.Encoder().encode(updatedTrip) else {
            return
        }

        Firestore.firestore().collection("preorder").document(trip.id).setData(encodedTrip) { _ in
            print("DEBUG: Updated pre-ordered trip state to accepted")
        }
    }

    func addTripObserverForDriver() {
        guard let currentUser = currentUser, currentUser.accountType == .driver else { return }

        Firestore.firestore().collection("trips")
            .whereField("driverUid", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                guard let change = snapshot?.documentChanges.first,
                      change.type == .added || change.type == .modified else { return }

                guard let trip = try? change.document.data(as: Trip.self) else { return }
                self.applyObservedTrip(trip, shouldUpdateRouteToPickup: true)
            }
    }
    func saveCompletedTripToUserCollection(_ trip: Trip) {
        guard let uid = currentUser?.uid else {
            print("Error: User ID is not available.")
            return
        }

        var updatedTrip = trip
        updatedTrip.distanceTraveled = distanceTraveled

        do {
            let tripData = try Firestore.Encoder().encode(updatedTrip)
            let db = Firestore.firestore()
            let userTripsRef = db.collection("users").document(uid).collection("user-trips").document(trip.id)

            userTripsRef.setData(tripData) { error in
                if let error = error {
                    print("Error saving completed trip to Firestore: \(error.localizedDescription)")
                } else {
                    print("Completed trip successfully saved to Firestore under user collection.")
                }
            }
        } catch {
            print("Error encoding trip data: \(error.localizedDescription)")
        }
    }
    func addPreorderObserverForDriver() {
        guard let currentUser = currentUser, currentUser.accountType == .driver else { return }

        Firestore.firestore().collection("preorder")
            .whereField("driverUid", isEqualTo: currentUser.uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                guard let change = snapshot?.documentChanges.first,
                      change.type == .added || change.type == .modified else { return }

                guard let trip = try? change.document.data(as: Trip.self) else { return }
                self.applyObservedTrip(trip, shouldUpdateRouteToPickup: true)
            }
    }

    func rejectTrip() {
        updateTripState(state: .rejected)
    }

    func acceptTrip() {
        updateTripState(state: .accepted)
    }

    func cancelTripAsDriver() {
        updateTripState(state: .driverCancelled)
    }

    func noTrip() {
        updateTripState(state: .noTrip)
    }
 

    func driverArrived() {
        updateTripState(state: .arrived)
    }

    func tripPreordered() {
        updateTripState(state: .preorder)
    }

    func startTrip() {
        updateTripState(state: .starttrip)
        startTrackingDistance()
        print("Trip started, tracking distance...")
    }

    func tripCompleted() {
        updateTripState(state: .tripCompleted)
        stopTrackingDistance()
        if let trip = trip {
            let finalCost = RideType.Economy.computePrice(for: distanceTraveled)
            print("Final trip cost: \(finalCost)")
            print("Total distance traveled: \(distanceTraveled) meters")

            Firestore.firestore().collection("trips").document(trip.id).updateData([
                "tripCost": finalCost,
                "distanceTraveled": distanceTraveled
            ]) { error in
                if let error = error {
                    print("Error updating trip data: \(error)")
                } else {
                    print("Trip data updated successfully")
                }
            }

            saveCompletedTrip(trip)
            saveCompletedTripToUserCollection(trip)
        }
    }
    private func startTrackingDistance() {
        distanceTraveled = 0.0
        lastLocation = locationManager.location // Initialize with current location
        isTrackingDistance = true
        print("isTrackingDistance set to true, lastLocation set to current location")
    }

    private func stopTrackingDistance() {
        isTrackingDistance = false
        print("Stopped tracking distance.")
    }
}

private extension TripState {
    var shouldUpdateDriverLocation: Bool {
        switch self {
        case .accepted, .arrived, .starttrip, .preorder:
            return true
        case .requested, .rejected, .noTrip, .passengerCancelled, .driverCancelled, .tripCompleted:
            return false
        }
    }

    var shouldRouteDriverToPickup: Bool {
        switch self {
        case .accepted, .arrived, .preorder:
            return true
        case .requested, .rejected, .noTrip, .passengerCancelled, .driverCancelled, .starttrip, .tripCompleted:
            return false
        }
    }

    var isTerminalForDriverSession: Bool {
        switch self {
        case .rejected, .noTrip, .passengerCancelled, .driverCancelled, .tripCompleted:
            return true
        case .requested, .accepted, .arrived, .starttrip, .preorder:
            return false
        }
    }
}

// MARK: - Location Search Helpers

extension HomeViewModel {
    func addressFromPlacemark(_ placemark: CLPlacemark) -> String {
        var result = ""
        if let thoroughtfare = placemark.thoroughfare {
            result += thoroughtfare
        }
        if let subthoroughtfare = placemark.subThoroughfare {
            result += " \(subthoroughtfare)"
        }
        if let subadministrativearea = placemark.subAdministrativeArea {
            result += ", \(subadministrativearea)"
        }
        return result
    }
    
    func getPlacemark(forLocation location: CLLocation, completion: @escaping(CLPlacemark?, Error?) -> Void) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let placemark = placemarks?.first else { return }
            completion(placemark, nil)
        }
    }
    
    func selectLocation(_ localSearch: MKLocalSearchCompletion, config: LocationResultsViewConfig) {
        locationSearch(forLocalSearchCompletion: localSearch) { response, error in
            guard let item = response?.mapItems.first else { return }
            let coordinate = item.placemark.coordinate
            
            switch config {
            case .ride:
                self.selectedUberLocation = UberLocation(title: localSearch.title, coordinate: coordinate)
            }
        }
    }
    
    func locationSearch(forLocalSearchCompletion localSearch: MKLocalSearchCompletion, completion: @escaping MKLocalSearch.CompletionHandler) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = localSearch.title.appending(localSearch.subtitle)
        let search = MKLocalSearch(request: searchRequest)
        search.start(completionHandler: completion)
    }
    
    func computeRidePrice(forType type: RideType) -> Double {
        guard let destCoordinate = selectedUberLocation else { return 0.0 }
        guard let userCoordinate = self.userLocation else { return 0.0 }
        
        let userLocation = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)
        let destination = CLLocation(latitude: destCoordinate.coordinate.latitude,
                                     longitude: destCoordinate.coordinate.longitude)
        let tripDistanceInMeters = userLocation.distance(from: destination)
        return type.computePrice(for: tripDistanceInMeters)
    }
    
    func createPickupAndDropoffRegionsForTrip() {
        guard let trip = trip else { return }
        LocationManager.shared.createPickupRegionForTrip(trip)
        LocationManager.shared.createDropoffRegionForTrip(trip)
    }
    
    func getDestinationRouteForAppleMaps(from userLocation: CLLocationCoordinate2D,
                                          to destinationCoordinate: CLLocationCoordinate2D,
                                          completion: @escaping (MKPolyline?, TimeInterval, Double) -> Void) {
        AppleMapsRouting.route(from: userLocation, to: destinationCoordinate) { route in
            if let route = route {
                completion(route.polyline, route.expectedTravelTime, route.distance)
                return
            }

            let distance = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
                .distance(from: CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude))
            let estimatedUrbanDrivingSpeedMetersPerSecond = 8.3
            completion(MKPolyline(coordinates: [userLocation, destinationCoordinate], count: 2),
                       distance / estimatedUrbanDrivingSpeedMetersPerSecond,
                       distance)
        }
    }
    
    func configurePickupAndDropOffTime(with expectedTravelTime: Double) {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        
        pickUpTime = formatter.string(from: Date())
        dropOffTime = formatter.string(from: Date() + expectedTravelTime)
    }
    
    func saveCompletedTrip(_ trip: Trip) {
        guard let uid = currentUser?.uid else {
            print("No user ID found.")
            return
        }
        
        let tripCost = trip.tripCost
        let deduction = tripCost * 0.12 // 12% of trip cost
        
        let ref = Database.database().reference()
        let walletRef = ref.child("Wallet").child(uid).child("amount")
        
        walletRef.runTransactionBlock { currentData in
            var value = currentData.value as? Double ?? 0.0
            value -= deduction
            currentData.value = value
            return TransactionResult.success(withValue: currentData)
        } andCompletionBlock: { error, committed, snapshot in
            if let error = error {
                print("Failed to update wallet balance: \(error.localizedDescription)")
            } else {
                print("Wallet balance updated successfully.")
            }
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        userRef.setData(["wallet": FieldValue.increment(-deduction)], merge: true) { error in
            if let error = error {
                print("Failed to update wallet balance in Firestore: \(error.localizedDescription)")
            } else {
                print("Wallet balance updated successfully in Firestore.")
            }
        }
    }

}
extension HomeViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.results = completer.results
    }
}
