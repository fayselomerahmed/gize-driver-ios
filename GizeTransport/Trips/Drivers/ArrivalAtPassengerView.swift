//
//  ArrivalAtPassengerView.swift
//  GizeDriver
//
//  Created by User on 10/11/23.
//

import SwiftUI

struct ArrivalAtPassengerView: View {
    @EnvironmentObject var viewModel: HomeViewModel
    var trip: Trip
    @StateObject private var GeoviewModel = GeoFireViewModel()
    
    var body: some View {
        VStack {
            // Bottom sheet
            Capsule()
                .foregroundColor(Color(.systemGray5))
                .frame(width: 48, height: 6)
                .padding(.top, 8)
            
            VStack(spacing: 12) {
                HStack {
                    SwipeButton(action: {
                        print("DEBUG: Arrived")
                        if viewModel.trip?.platform == "IOS" {
                            viewModel.startTrip()
                        }else {
                            GeoviewModel.createGeoFireDestinationLocation(key: trip.passengerUid, destination: trip.dropoffLocationCoordinates)
                            viewModel.startTrip()
                        }
                        }) {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.white)
                            Text("Start Trip")
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
                
                Divider()
                
                // Passenger Information
                HStack {
                    Image("logo") // Replace with your actual image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.passengerName)
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(Color(.systemYellow))
                                .imageScale(.small)
                            // Uncomment if needed
                            // Text("4.8")
                            //    .font(.footnote)
                            //    .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Earnings")
                        
                        Text("\(trip.tripCost.toCurrency())")
                            .font(.system(size: 24, weight: .semibold))
                    }
                }
                .padding()
                
                Divider()
                
                HStack {
                    Button(action: {
                        print("DEBUG: Cancel trip")
                        viewModel.cancelTripAsDriver()
                        viewModel.deleteTrip()
                    }) {
                        Text("CANCEL TRIP")
                            .fontWeight(.bold)
                            .frame(width: UIScreen.main.bounds.width - 245, height: 50)
                            .background(Color.red)
                            .cornerRadius(10)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.theme.backgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
        }
        .padding(.bottom, 24)
        .background(Color.theme.backgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
    }
}




