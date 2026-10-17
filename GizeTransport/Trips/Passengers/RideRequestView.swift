//
//  RideRequestView.swift
//  GizeDriver
//
//  Created by User on 10/8/23.
//
//
//import SwiftUI
//
//struct RideRequestView: View {
//    @State private var selectedRideType: RideType = .Economy
//    @Environment (\.dismiss) var dismiss
//    @EnvironmentObject var homeViewModel: HomeViewModel
//    @State private var isShowDate: Bool = false
//    @State private var date = Date()
//    @State private var time = Date().formatted(date: .complete, time: .standard)
//    @State private var isSheetPresented = false
//    var body: some View {
//        VStack {
//            Capsule()
//                .foregroundColor(Color(.systemGray5))
//                .frame(width: 48 , height: 6)
//                .padding(.top, 8 )
//            HStack {
//                VStack {
//                    Circle()
//                        .fill (Color(.systemGray3))
//                        .frame(width: 8 , height: 8)
//                    
//                    Rectangle()
//                        .fill (Color(.systemGray3))
//                        .frame(width: 1 , height: 32)
//                    Rectangle()
//                        .fill (.black)
//                        .frame(width: 8 , height: 8)
//                }
//                
//                VStack(alignment: .leading, spacing: 24) {
//                    HStack{
//                        
//                        Text("Current location")
//                            .font(.system(size:16,weight: .semibold))
//                            .foregroundColor(.gray)
//                        Spacer()
//                        Text(homeViewModel.pickUpTime ?? "")
//                            .foregroundColor(.gray)
//                    }
//                    .padding(.bottom,10)
//                    HStack{
//                        if let location = homeViewModel.selectedUberLocation {
//                            Text(location.title)
//                                .font(.system(size:16,weight: .semibold))
//                                .foregroundColor(.black)
//                            Spacer()
//                            Text(homeViewModel.dropOffTime ?? "")
//                                .font(.system(size:14,weight: .semibold))
//                                .foregroundColor(.gray)
//                        }
//                    }
//                    
//                }.padding(.leading, 8)
//            }.padding()
//            Divider()
//            Text ("SUGGESTED RIDES")
//                .font(.subheadline)
//                .fontWeight(.semibold)
//                .padding()
//                .foregroundColor(.gray)
//                .frame(maxWidth: .infinity,alignment: .leading)
//            
//            ScrollView(.horizontal) {
//                HStack(spacing: 12 ) {
//                    ForEach(RideType.allCases){ type in
//                        VStack(alignment: .leading){
//                            Image(type.imageName)
//                                .resizable()
//                                .scaledToFit()
//                            VStack(alignment: .leading, spacing: 4) {
//                                Text (type.description)
//                                    .font(.system(size:14,weight: .semibold))
//                                
//                                Text (homeViewModel.computeRidePrice(forType: type).toCurrency())
//                                    .font(.system(size:14,weight: .semibold))
//                            }
//                            .padding(8)
//                        }.frame(width: 112 ,height: 140)
//                            .foregroundColor(type == selectedRideType ? .white : Color.theme.primaryTextColor)
//                            .background(type == selectedRideType ? .blue : Color.theme.secondaryBackgroundColor)
//                            .cornerRadius(20)
//                            .scaleEffect(type == selectedRideType ? 1.15 : 1.0)
//                            .onTapGesture {
//                                withAnimation(.spring()){
//                                    selectedRideType = type
//                                }
//                                
//                            }
//                        
//                    }
//                    
//                    
//                    
//                    
//                    
//                }
//                
//                Divider()
//                    .background (Color.theme.secondaryBackgroundColor)
//                    .cornerRadius(20)
//                    .padding(.bottom)
//                
//                
//                //                VStack(alignment: .trailing) {
//                //                    Button {
//                //                        isShowDate.toggle()
//                //                    } label: {
//                //                        Image(systemName: "calendar")
//                //                            .background(.blue)
//                //                            .cornerRadius(2)
//                //                            .foregroundColor(.white)
//                //                            .padding(.bottom, 5)
//                //                            .scaledToFit()
//                //
//                //                            .sheet(isPresented: $isShowDate) {
//                //                                DatePicker(
//                //                                    "Booking Date & time",
//                //                                    selection: $date,
//                //                                    displayedComponents: [.date, .hourAndMinute]
//                //                                )
//                //
//                //                                .foregroundColor(.black)
//                //                                .datePickerStyle(.graphical)
//                //                                Button {
//                //                                    isShowDate.toggle()
//                //                                } label: {
//                //                                    Text ("Done")
//                //                                        .fontWeight(.bold)
//                //                                        .frame(width: UIScreen.main.bounds.width - 32 ,height: 50 )
//                //                                        .background(.blue)
//                //                                        .cornerRadius(10)
//                //                                        .foregroundColor(.white)
//                //
//                //                                }
//                
//                //                }
//                
//                
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 3)
//            HStack {
//                Button {
//                    homeViewModel.requestTrip()
//                } label: {
//                    Text("CONFIRM RIDE")
//                        .fontWeight(.bold)
//                        .frame(width: UIScreen.main.bounds.width - 32 ,height: 50 )
//                        .background(.blue)
//                        .cornerRadius(10)
//                        .foregroundColor(.white)
//                }
//                
//             
//            }
//        }
//        .padding(.bottom, 24)
//     
//        .background(Color.theme.backgroundColor)
//        .cornerRadius(35)
//          
//    }
//    }
//
//struct RideRequestView_Previews: PreviewProvider {
//    static var previews: some View {
//        RideRequestView()
//    }
//}
