import SwiftUI
import FirebaseDatabase
import CoreLocation

struct TripStartedView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    let trip: Trip

    var body: some View {
        VStack {
            Capsule()
                .foregroundColor(Color(.systemGray5))
                .frame(width: 48, height: 6)
                .padding(.top, 8)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trip in Progress")
                            .font(.largeTitle)
                        Text("The Estimated arrival time is 2:20 PM")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(.darkGreen))
                    }
                    .padding()

                    Spacer()

                    RideInProgressSpinner(lineWidth: 4, height: 44, width: 44)
                        .padding()
                }

                // Swipe to End Trip Button
                HStack {
                    SwipeButton(action: {
                        completeTrip()
                    }) {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.white)
                            Text("End Trip")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 50)
                    .background(Color.gray)
                    .cornerRadius(10)

                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .background(Color.theme.backgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
    }

    private func completeTrip() {
        // Safeguard to ensure trip state update conflicts are avoided
        guard homeViewModel.trip?.state != .tripCompleted else {
            print("Trip is already completed. No further action needed.")
            return
        }

        // Update trip in Firebase Realtime Database
        let updateTrip: [String: Any] = ["done": true, "state": TripState.tripCompleted.rawValue]
        let ref = Database.database().reference(withPath: "Trips").child(homeViewModel.trip?.tripId ?? "")

        ref.updateChildValues(updateTrip) { error, _ in
            if let error = error {
                print("Failed to update trip status: \(error.localizedDescription)")
                return
            }

            // Handle location and complete the trip
            checkAndFetchLocation()
            processTripCompletion()
        }
    }

    private func processTripCompletion() {
        // Update local state and backend state to "trip completed"
//        homeViewModel.updateTripState(state: .tripCompleted)

        // Platform-specific completion handling
        if homeViewModel.trip?.platform == "IOS" {
            homeViewModel.tripCompleted()
        } else {
            homeViewModel.deleteNestedDataForUserDestination(uid: homeViewModel.trip?.passengerUid ?? "")
            homeViewModel.deleteNestedDataForUser(uid: homeViewModel.trip?.passengerUid ?? "")
            homeViewModel.sendFCMMessageDone()
        }

        // Save the completed trip and finish the process
        homeViewModel.saveCompletedTrip(trip)
//        homeViewModel.tripCompleted()
    }

    private func checkAndFetchLocation() {
        let locationManager = CLLocationManager()

        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
            if let location = locationManager.location {
                AppLogger.info("Trip location updated.")
            }
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

