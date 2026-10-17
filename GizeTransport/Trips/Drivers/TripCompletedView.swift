import SwiftUI

struct TripCompletedView: View {
    var trip: Trip
    @Binding var isPresented: Bool
    @State private var showTripDetails: Bool = false
    @EnvironmentObject var homeViewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                // Total Trip Cost Section
                Text("TOTAL")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("ETB \(trip.tripCost, specifier: "%.2f")")
                    .font(.largeTitle)
                    .fontWeight(.bold)


                // Button to toggle Trip Details
                Button(action: {
                    withAnimation {
                        showTripDetails.toggle()
                    }
                }) {
                    HStack {
                        Text("Trip Details")
                        Image(systemName: showTripDetails ? "chevron.up" : "chevron.down")
                    }
                    .foregroundColor(.black)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(5)
                    .shadow(radius: 2)
                }

                // Detailed Trip Information
                if showTripDetails {
                    VStack {
                        detailView(title: "Start Location:", value: trip.pickupLocationName)
                        detailView(title: "End Location:", value: trip.dropofflocationName)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }

                // Passenger Information Section
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray)
                    Text(trip.passengerName)
                        .font(.headline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .shadow(radius: 5)

                // OK Button to end the trip
                Button("OK") {
                    homeViewModel.noTrip()
                    isPresented = false
                }
                .font(.title3)
                .foregroundColor(.white)
                .padding()
                .frame(width: UIScreen.main.bounds.width * 0.8, height: 50)
                .background(Color.green)
                .cornerRadius(25)
                .shadow(radius: 10)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 5)

            Spacer()
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    func detailView(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(Color.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color.primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

