//
//  AcceptTripView.swift
//  GizeTransport
//
//  Created by User on 6/1/23.
//
import SwiftUI
import MapKit
import FirebaseFirestore
import FirebaseMessaging

struct AcceptTripView: View {
    @State private var region: MKCoordinateRegion
    let trip: Trip
    let tripIDToDelete = "tripId"
    let annotationItem: UberLocation
    @EnvironmentObject var viewModel: HomeViewModel
    @State private var timeRemaining: TimeInterval = 15
    @State private var timer: Timer?
    @StateObject private var geoViewModel = GeoFireViewModel()

    init(trip: Trip) {
        let center = CLLocationCoordinate2D(latitude: trip.pickupLocationCoordiantes.latitude, longitude: trip.pickupLocationCoordiantes.longitude)
        let span = MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        self._region = State(initialValue: MKCoordinateRegion(center: center, span: span))
        self.trip = trip
        self.annotationItem = UberLocation(title: trip.pickupLocationName, coordinate: trip.pickupLocationCoordiantes)
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.theme.mutedText.opacity(0.25))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            requestHeader
            passengerCard
            routeCard
            actionRow
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .gizePanel()
        .onAppear {
            startTimer()
            viewModel.fetchPassengerPhoneNumber(uid: trip.passengerUid)
        }
        .onDisappear(perform: stopTimer)
    }

    private var requestHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("New ride request")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Color.theme.ink)

                Text("Pickup at \(trip.pickupLocationName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.theme.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            ZStack {
                CircularProgressBar(progress: max(timeRemaining, 0) / 15)
                    .frame(width: 62, height: 62)

                VStack(spacing: 1) {
                    Text("\(Int(max(timeRemaining, 0)))")
                        .font(.system(size: 20, weight: .bold))
                    Text("sec")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(Color.theme.ink)
            }
        }
    }

    private var passengerCard: some View {
        HStack(spacing: 14) {
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.passengerName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.theme.ink)

                Text("Passenger • iOS request")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.theme.mutedText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text("Earnings")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.theme.mutedText)

                Text(trip.tripCost.toCurrency())
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Color.theme.darkGreen)
            }
        }
        .padding(14)
        .background(Color.theme.softSurface)
        .clipShape(RoundedRectangle(cornerRadius: GizeUI.corner, style: .continuous))
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                routeMetric(title: "Pickup", value: trip.pickupLocationName, icon: "mappin.circle.fill")
                routeMetric(title: "Distance", value: trip.distanceToPassenger.distanceInKilometersString(), icon: "point.topleft.down.curvedto.point.bottomright.up")
            }

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.theme.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Destination")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.theme.mutedText)
                    Text(trip.dropofflocationName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.theme.ink)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Color.theme.fieldSurface)
        .clipShape(RoundedRectangle(cornerRadius: GizeUI.corner, style: .continuous))
    }

    private func routeMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.theme.darkGreen)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.theme.mutedText)
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                rejectTrip()
            } label: {
                Text("Pass")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 92, height: 52)
                    .foregroundColor(Color.theme.danger)
                    .background(Color.theme.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())

            SwipeButton(action: {
                acceptTrip()
            }) {
                HStack {
                    Image(systemName: "car.fill")
                    Text("Swipe to accept")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
            }
            .frame(height: 52)
            .background(Color.theme.darkGreen)
            .cornerRadius(GizeUI.compactCorner)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timeRemaining = 15
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            timeRemaining -= 1
            if timeRemaining <= 0 {
                rejectTrip()
                viewModel.trip?.state = .rejected
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func rejectTrip() {
        stopTimer()
        viewModel.rejectTrip()
    }

    private func acceptTrip() {
        stopTimer()
        if viewModel.trip?.platform == "IOS" {
            viewModel.acceptTrip()
        } else {
            viewModel.acceptTrip()
            geoViewModel.createGeoFirePickupLocation(key: trip.passengerUid, destination: trip.pickupLocationCoordiantes)
            viewModel.AcceptTripForRealTime()
            viewModel.sendFCMMessage()
        }

        FCMNotificationManager.shared.sendMessageToPassenger(passengerId: trip.passengerUid, title: "Your ride has been accepted!", body: "Driver \(trip.driverName) is on the way to pick you up.")
    }
}

struct CircularProgressBar: View {
    var progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .foregroundColor(Color.theme.darkGreen.opacity(0.18))

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1)))
                .stroke(style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .foregroundColor(Color.theme.darkGreen)
                .rotationEffect(Angle(degrees: 270))
                .animation(.linear, value: progress)
        }
    }
}
