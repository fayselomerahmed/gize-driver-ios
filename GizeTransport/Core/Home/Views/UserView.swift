//
//  UserView.swift
//  GizeDriver
//
//  Created by User on 4/29/24.
//
//import SwiftUI
//
//struct UserView: View {
//    @StateObject private var viewModel = UserViewModel()
//    @State private var phoneNumber = ""  // State to hold the phone number input
//    @EnvironmentObject var homeViewModel: HomeViewModel
//
//    var body: some View {
//        VStack {
//            TextField("Enter phone number", text: $phoneNumber)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding()
//                .keyboardType(.numberPad)
//
//            if let user = viewModel.user {
//                Text("User: \(user.fullname)")
//                // Display more user details
//            } else if let errorMessage = viewModel.errorMessage {
//                Text(errorMessage).foregroundColor(.red)
//            }
//
//            Button("Fetch Passenger and Start Trip") {
//                viewModel.getUserByPhoneNumber(phoneNumber)
//            }
//            .frame(width: UIScreen.main.bounds.width - 32, height: 50)
//            .background(Color.blue)
//            .cornerRadius(10)
//            .foregroundColor(.white)
//            .font(.system(size: 16, weight: .bold))
//            .padding()
//            .disabled(phoneNumber.isEmpty)  // Disable button if phone number is empty
//        }
//        .padding()
//        .background(Color.theme.backgroundColor)
//        .onAppear {
//            viewModel.onUserFetched = { user in
//                homeViewModel.selectedPassenger = user
//                DispatchQueue.main.async {
//                    homeViewModel.startManualTrip(withPassengerUid: user.uid)
//                    homeViewModel.sendFCMNotificationForManual()
//                    homeViewModel.sendFCMMessageManualTrip(with: user.fcmToken)
//                }
//            }
//        }
//    }
//}
//
