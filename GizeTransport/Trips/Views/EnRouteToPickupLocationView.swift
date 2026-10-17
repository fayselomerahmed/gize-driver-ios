//
//  EnRouteToPickupLocationView.swift
//  UberSwiftUI
//
//  


import SwiftUI

struct EnRouteToPickupLocationView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    let user: User?
    let trip:Trip?
    var body: some View {
        VStack {
            Capsule()
                .foregroundColor(Color(.systemGray5))
                .frame(width: 48, height: 6)
                .padding(8)
            
            if let user = user {
                VStack(alignment: .leading) {
                    
                    if let trip = homeViewModel.trip {
                        HStack {
                            if user.accountType == .passenger {
                                Text("Meet your driver at \(trip.pickupLocationName)")
                                    .font(.body)
                            } else {
                                Text("Pickup \(trip.passengerName) at \(trip.pickupLocationName)")
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .frame(height: 44)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            EstimatedTimeArrivalView(time: trip.distanceToPassenger.distanceInKilometersString())
                        }
                        .padding()
                        
                        Divider()
                            .padding(.top, 8)

                        if user.accountType == .passenger {
                            HStack {
                               Image("logo")
                                    .padding(.leading)
                                
                                Spacer()
                                
                                DriverVehicleInfoView()
                                    .padding(.trailing)
                            }
                        } else {
                            HStack {
                                TripInfoView(trip: trip, user: user)
                                    .padding(.vertical)
                            }
                        }
                    }

                    Divider()
                }
            }
            
            Button {
                homeViewModel.cancelTripAsDriver()
      
            } label: {
                Text("CANCEL TRIP")
                    .fontWeight(.bold)
                    .frame(width: UIScreen.main.bounds.width - 64, height: 50)
                    .background(Color(.systemRed))
                    .cornerRadius(10)
                    .foregroundColor(.white)
            }
            .padding()
            
            Spacer()
        }
        .background(Color.theme.backgroundColor)
//        .clipShape(RoundedShape(corners: [.topLeft, .topRight]))
        .frame(height: 350)
        .shadow(color: .black, radius: 10, x: 0, y: 0)
    }
}


