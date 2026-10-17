//
//  PreOrder.swift
//  GizeDriver
//
//  Created by User on 10/7/23.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PreOrder: View {
    @EnvironmentObject var homeViewModel: HomeViewModel


    var body: some View {
        NavigationView {
            VStack {
//                HeaderView()
                ContentListView()
            }
            .navigationTitle("Pre-Orders")
            .onAppear {
                homeViewModel.listenForPreorders()
            }
        }
        .background(Color.white)
    }

    struct HeaderView: View {
        var body: some View {
            HStack {
//                Button(action: {
//                    // Action for back button
//                }) {
//                    Image(systemName: "arrow.left")
//                        .font(.title)
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.green)
//                        .clipShape(Circle())
//                }
                Spacer()
            }
            .padding()
        }
    }

    struct ContentListView: View {
        @EnvironmentObject var homeViewModel: HomeViewModel
   
        var body: some View {
            if homeViewModel.trips.isEmpty {
                EmptyView()
            } else {
                ScrollView {
                    ForEach(homeViewModel.trips) { trip in
                        TripView(trip: trip)
                    }
                }
            }
        }

        struct EmptyView: View {
            var body: some View {
                Text("No Pre-Orders Available")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding()
            }
        }

        struct TripView: View {
            @EnvironmentObject var homeViewModel: HomeViewModel
            var trip: Trip
            var selectedPassenger: Passenger?
            var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(formattedDateTime(from: Date()))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }

                    Divider()

                    HStack(alignment: .top, spacing: 10) {
                        VStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: "circle.fill")
                                .foregroundColor(.black)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(trip.pickupLocationAddress)
                                .font(.headline)
                            Text(trip.dropofflocationName)
                                .font(.headline)
                        }
                    }

                    Button(action: {
                        homeViewModel.sendFCMMessageManualTrip(with: selectedPassenger?.fcmToken ?? "")
                        homeViewModel.startTrip(trip: trip)
                    }) {
                        Text("Start Trip")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
            }

            // Function to format date as needed
            func formattedDateTime(from date: Date?) -> String {
                guard let date = date else {
                    return "N/A"
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, yyyy HH:mm"
                return dateFormatter.string(from: date)
            }
        }
    }
}

struct PreOrder_Previews: PreviewProvider {
    static var previews: some View {
        PreOrder()
            .environmentObject(HomeViewModel())
    }
}
