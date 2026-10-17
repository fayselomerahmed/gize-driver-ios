//
//  PreOrderView.swift
//  GizeDriver
//
//  Created by User on 10/8/23.
//

import SwiftUI

struct PreOrderView: View {
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()

    var body: some View {
        VStack {
            DatePicker("Select Date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                .padding()

            DatePicker("Select Time", selection: $selectedTime, in: Date()..., displayedComponents: .hourAndMinute)
                .padding()

            Button("Start Pre-ordered Trip") {
                homeViewModel.startPreorderedTrip(date: selectedDate, time: selectedTime)
            }
        }
        .padding()
        .background(Color(.systemGray3))
    }
}
