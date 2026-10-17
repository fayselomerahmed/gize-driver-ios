//
//  LocationSearchView.swift
//  UberSwiftUitutorial
//
//  Created by User on 12/6/22.
//

import SwiftUI

struct LocationSearchView: View {
    @State private var startLocationText = "Current Location"
    @EnvironmentObject var viewModel: HomeViewModel
    @ObservedObject private var userViewModel = UserViewModel()
    @State private var phoneNumber = ""
    @State private var isLoading = false

    // Add these environment properties
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Input Fields
                VStack(spacing: 16) {
                    headerView
                    inputFields
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 5)

                // Divider
                Divider()
                    .padding(.vertical, 8)

                // Search Results
                LocationSearchResultsView(viewModel: viewModel, config: .ride)
                    .onChange(of: viewModel.selectedUberLocation) { newLocation in
                        viewModel.queryFragment = newLocation?.title ?? ""
                        viewModel.clearSearchResults()
                    }

                Spacer()
            }
            .background(Color.theme.backgroundColor)
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitle("Manual Trip", displayMode: .inline)
            .navigationBarItems(leading: dismissButton)
            .onAppear(perform: onAppear)
            .overlay(
                loadingOverlay
            )
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                Circle()
                    .fill(Color.darkGreen)
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 2, height: 24)

                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }

            VStack(spacing: 12) {
                TextField("Current Location", text: $startLocationText)
                    .disabled(true)
                    .customTextFieldStyle()

                TextField("Where to?", text: $viewModel.queryFragment)
                    .customTextFieldStyle()
            }
        }
    }

    // MARK: - Input Fields

    private var inputFields: some View {
        VStack(spacing: 16) {
            TextField("Enter Passenger's Phone Number", text: $phoneNumber)
                .keyboardType(.numberPad)
                .customTextFieldStyle()

            if let passenger = userViewModel.passenger {
                Text("Passenger: \(passenger.fullname)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else if let errorMessage = userViewModel.errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.red)
            }

            Button(action: fetchPassengerAndStartTrip) {
                Text("Fetch Passenger and Start Trip")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.darkGreen)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(phoneNumber.isEmpty || isLoading)
            .opacity(phoneNumber.isEmpty || isLoading ? 0.5 : 1.0)
        }
        .padding(.top, 16)
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: {
            // Dismiss the view
            if #available(iOS 15.0, *) {
                dismiss()
            } else {
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.black)
        }
    }

    // MARK: - Loading Overlay

    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)

                ProgressView("Loading...")
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.darkGreen))
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Functions

    private func onAppear() {
        // Reset fields when the view appears
        resetFields()

        userViewModel.onPassengerFetched = { passenger in
            viewModel.selectedPassenger = passenger
            DispatchQueue.main.async {
                viewModel.requestTrip()
                viewModel.sendFCMNotificationForManual()
                viewModel.sendFCMMessageManualTrip(with: passenger.fcmToken)
                self.isLoading = false

                // Reset fields after starting the trip
                resetFields()

                // Dismiss the view after starting the trip
                if #available(iOS 15.0, *) {
                    dismiss()
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func fetchPassengerAndStartTrip() {
        self.isLoading = true
        userViewModel.getPassengerByPhoneNumber(phoneNumber)
    }

    // MARK: - Reset Fields

    private func resetFields() {
        self.startLocationText = "Current Location"
        self.viewModel.queryFragment = ""
        self.phoneNumber = ""
        self.userViewModel.passenger = nil
        self.userViewModel.errorMessage = nil
        self.viewModel.selectedUberLocation = nil
        self.viewModel.searchResults = []
    }
}

// MARK: - Custom TextField Modifier and Extension

struct CustomTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

extension View {
    func customTextFieldStyle() -> some View {
        self.modifier(CustomTextFieldModifier())
    }
}

// MARK: - Preview

struct LocationSearchView_Previews: PreviewProvider {
    static var previews: some View {
        LocationSearchView()
            .environmentObject(HomeViewModel())
    }
}
