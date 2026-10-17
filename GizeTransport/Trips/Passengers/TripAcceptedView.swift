//
//  TripAccptedView.swift
//  GizeDriver
//
//  Created by User on 7/15/23.
//

import SwiftUI

struct TripAcceptedView: View {
    @EnvironmentObject var viewModel : HomeViewModel
    @State private var isSheetPresented = false
    var body: some View {
        VStack {
            Capsule()
                .foregroundColor(Color(.systemGray5))
                .frame(width: 48 , height: 6)
                .padding(.top, 8 )
            if let trip = viewModel.trip {
                VStack {
                    HStack {
                        Text("Meet your driver at \(trip.pickupLocationName) for your trip to \(trip.dropofflocationName)")
                            .font(.body)
                            .frame(height: 44)
                            .lineLimit(2)
                        .padding(.trailing)
                        
                        Spacer()
                        VStack {
                            Text("\(trip.travelTimeToPassenger)")
                                .bold()
                            
                            Text ("min")
                                .bold()
                        }
                        .frame(width: 56 , height: 56)
                        .foregroundColor(.white)
                        .background(Color(.darkGreen))
                        .cornerRadius(10)
                    }
                    .padding()
                    Divider()
                    
                }
                // driver info view
                VStack {
                    HStack {
                        Image("logo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80 , height: 80)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.driverName)
                                .fontWeight(.bold)
                            
//                            HStack {
//                                Image(systemName: "star.fill")
//                                    .foregroundColor(Color(.systemYellow))
//                                    .imageScale(.small)
//                                Text ("4.8")
//                                    .font(.footnote)
//                                    .foregroundColor(.gray)
//                            }
                        }
                        
                        Spacer()
                        
                      // driver vehicle info
                        
                        VStack(alignment: .center) {
                            Image ("uber-black")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120 , height: 64)
                            
                            HStack {
                                Text("Toyota Vitz")
                                    .font(.system(size: 14,weight: .semibold))
                                    .foregroundColor(.gray)
                                Text ("A55761-02")
                                    .font(.system(size: 14,weight: .semibold))
                            }
                            .frame(width: 160)
                            .padding(.bottom)
                            
                        }
                    }
                    
                    Divider()
                    
                    
                }
                .padding()
                
             
            }
            HStack {
                Button {
                    viewModel.driverArrived()
                } label: {
                    Text("Arrived at Destination")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding()
                        .frame(width: (UIScreen.main.bounds.width / 2) - 64 ,height: 56)
                        .background(Color(.darkGreen))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                }
                Button {
                    viewModel.cancelTripAsPassenger()
                    print("DEBUG: Cancel trip")
                } label: {
                    Text("CANCEL TRIP")
                        .fontWeight(.bold)
                        .frame(width: UIScreen.main.bounds.width - 32 ,height: 50 )
                        .background(.red)
                        .cornerRadius(10)
                        .foregroundColor(.white)
                    
                }
            }
            .padding(.top)
             .padding(.horizontal)
             .padding(.bottom, 30)
        } 
        .background(Color.theme.backgroundColor)
            .cornerRadius(16)
            .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
 
    }
}

struct TripAcceptedView_Previews: PreviewProvider {
    static var previews: some View {
        TripAcceptedView()
    }
}

