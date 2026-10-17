//
//  LoadingView.swift
//  GizeDriver
//
//  Created by User on 5/18/24.
//
import SwiftUI
import Network
struct LoadingView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @Binding var isLoading: Bool

    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .frame(width: 150, height: 150)
                .padding()

            if networkManager.isConnected {
                Text("Gize Transport")
                    .font(.headline)
                ProgressView()
            } else {
                Text("No Internet Connection")
                    .font(.headline)
                    .foregroundColor(.red)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3).edgesIgnoringSafeArea(.all))
        .transition(.opacity)
    }
}


