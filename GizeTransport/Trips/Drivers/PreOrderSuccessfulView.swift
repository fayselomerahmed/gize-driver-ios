//
//  PreOrderSuccessfulView.swift
//  GizeDriver
//
//  Created by User on 10/12/23.
//

import SwiftUI

struct PreOrderSuccessView: View {
    @State private var showingPopup = false

    var body: some View {
        Button("Show Preorder Success") {
            showingPopup = true
        }
        .sheet(isPresented: $showingPopup) {
            PreorderSuccessfulView(showingPopup: $showingPopup)
        }
    }
}

struct PreorderSuccessfulView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @Binding var showingPopup: Bool

    var body: some View {
        VStack {
            Text("Preorder Successful!")
                .font(.title)
                .fontWeight(.bold)
                .padding()

            Spacer()

            Button(action: {
                if let tripId = homeViewModel.trip?.tripId {
                    homeViewModel.markTripAsDone(tripId: tripId)
                }
                homeViewModel.noTrip()
                showingPopup = false // Dismiss the popup
            }) {
                Text("Dismiss")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(Color.darkGreen)
                    .cornerRadius(10)
            }
            .padding()
        }
        .frame(width: 300, height: 200)
        .background(Color.theme.backgroundColor)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

struct PreorderSuccessfulView_Previews: PreviewProvider {
    static var previews: some View {
        PreorderSuccessfulView(showingPopup: .constant(true)).environmentObject(HomeViewModel())
    }
}
