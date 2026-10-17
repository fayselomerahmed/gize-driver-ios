//
//  AcceptPreOrderTripView.swift
//  GizeDriver
//
//  Created by User on 10/12/23.
//

import SwiftUI
import MapKit

struct AcceptPreOrderTripView: View {
    @State private var region: MKCoordinateRegion
    let trip: Trip
    let tripIDToDelete = "tripId"
    let annotationItem: UberLocation
    @EnvironmentObject var viewModel: HomeViewModel
    @State private var timeRemaining: TimeInterval = 15
    @State private var timer: Timer?
    @StateObject private var geoViewModel = GeoFireViewModel()
    
    init(trip: Trip) {
        let center = CLLocationCoordinate2D(latitude: trip.pickupLocationCoordiantes.latitude, longitude: trip.pickupLocationCoordiantes.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        self._region = State(initialValue: MKCoordinateRegion(center: center, span: span))
        self.trip = trip
        self.annotationItem = UberLocation(title: trip.pickupLocationName, coordinate: trip.pickupLocationCoordiantes)
    }
    
    var body: some View {
        VStack {
            Capsule()
                .foregroundColor(Color(.systemGray5))
                .frame(width: 48, height: 6)
                .padding(.top, 8)
            
            VStack {
                HStack {
                    Text("Would you like to pick up this passenger at \(trip.pickupLocationName)?")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: 44)
                    
                    Spacer()
                
                    ZStack {
                        VStack {
                            Button(action: {
                                rejectTrip()
                            }) {
                                Text("Pass")
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.red)
                                    .cornerRadius(10)
                            }
                            Spacer().frame(height: 8) // Space between button and progress bar
                            
                            ZStack {
                                CircularProgressBar(progress: timeRemaining / 15)
                                    .frame(width: 56, height: 56)
                                
                                VStack {
                                    Text("\(trip.travelTimeToPassenger)")
                                        .bold()
                                    
                                    Text("min")
                                        .bold()
                                }
                                .background(Color.theme.backgroundColor)
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
                Divider()
            }
            
            // User info view
            VStack {
                HStack {
                    Image("logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.passengerName)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 6) {
                        Text("Earnings")
                        
                        Text(trip.tripCost.toCurrency())
                            .font(.system(size: 24, weight: .semibold))
                    }
                }
                
                Divider()
            }
            .padding()
            
            // Pickup location info view
            VStack {
                // Trip location info
                HStack {
                    // Address info
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To: \(trip.dropofflocationName)")
                            .font(.headline)
                        
                        Text(trip.pickupLocationAddress)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    // Distance
                    VStack {
                        Text(trip.distanceToPassenger.distanceInKilometersString())
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("miles")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                
                Divider()
            }
            
            // Swipe to Accept Button
            HStack {
                SwipeButton(action: {
                    acceptTrip()
                }) {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.white)
                        Text("Swipe to Accept")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .frame(height: 50)
                .background(Color.green)
                .cornerRadius(10)
                
                Spacer()
            }
            .padding(.top)
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .cornerRadius(16)
        .background(Color.theme.backgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
        .onAppear(perform: {
            startTimer()
            viewModel.fetchPassengerPhoneNumber(uid: trip.passengerUid)
        })
        .onDisappear(perform: stopTimer)
    }
    
    private func startTimer() {
        timer?.invalidate()
        timeRemaining = 15
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeRemaining -= 1
            if timeRemaining <= 0 {
                rejectTrip()
                viewModel.trip?.state = .rejected
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func rejectTrip() {
        stopTimer()
        viewModel.rejectTrip()
    }
    
    private func acceptTrip() {
        stopTimer()
        viewModel.tripPreordered()
        if trip.platform == "IOS" {
            viewModel.handlePreorderedTripRequest(trip, documentID: "preorder")
            viewModel.tripPreordered()
        } else {
            viewModel.sendFCMNotificationForPreorder()
//            viewModel.sendFCMMessagePreorder(with: trip.fcmToken ?? "")
            viewModel.tripPreordered()
        }
        }
}

// SwipeButton Component (unchanged)

// CircularProgressBar Component (unchanged)


// Mock data for previews (unchanged)

