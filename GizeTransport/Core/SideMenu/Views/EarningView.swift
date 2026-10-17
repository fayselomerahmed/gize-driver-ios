//
//  EarningView.swift
//  GizeDriver
//
//  Created by User on 6/8/24.
//
import SwiftUI

struct EarningsView: View {
    @Binding var todaysEarnings: Double
    @EnvironmentObject var homeViewModel: HomeViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("TODAY'S EARNING")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("ETB \(todaysEarnings, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Spacer()
            VStack(alignment: .leading) {
                Text(" WALLET")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Text("ETB \(homeViewModel.walletBalance, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.darkGreen)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}
