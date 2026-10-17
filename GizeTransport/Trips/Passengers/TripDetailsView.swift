//
//  TripDetailView.swift
//  GizeTransportDriver
//
//  Created by User on 8/19/23.
//
//import SwiftUI
//
//struct TripDetailsView: View {
//    let trip: Trip
//    @EnvironmentObject var viewModel : HomeViewModel
//    @Environment (\.dismiss) var dismiss
//    var body: some View {
//        VStack(spacing: 20) {
//            Text("Trip Details")
//                .font(.largeTitle)
//                .bold()
//            
//            HStack {
//                Image(systemName: "location.circle.fill")
//                    .foregroundColor(.blue)
//                Text("Pickup at: \(trip.pickupLocationName)")
//            }
//            
//            HStack {
//                Image(systemName: "location.circle.fill")
//                    .foregroundColor(.green)
//                Text("Dropoff at : \(trip.dropofflocationName)")
//            }
//            
//            HStack {
//                Image(systemName: "dollarsign.circle.fill")
//                    .foregroundColor(.purple)
//                Text("Fare: \(trip.tripCost)")
//            }
//            
//            // Other trip details can be added here
//            Button {
//                viewModel.noTrip()
//
//            print("DEBUG: Arrived to destination")
//            } label: {
//                Text("Done")
//                    .fontWeight(.bold)
//                    .frame(width: UIScreen.main.bounds.width - 32 ,height: 50 )
//                    .background(.blue)
//                    .cornerRadius(10)
//                    .foregroundColor(.white)
//               
//            }
//            Spacer()
//        }
//        .frame(width: 500 ,height: 250 )
//        .padding(.bottom , 24)
//        .background(Color.theme.backgroundColor)
//            .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
//            .cornerRadius(100)
//    }
//}
//
//struct TripDetailsView_Previews: PreviewProvider {
//    static var previews: some View {
//        TripDetailsView (trip: dev.mockTrip)
//    }
//}
//
