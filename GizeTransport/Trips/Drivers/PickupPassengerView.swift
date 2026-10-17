//
//  PickupPassengerView.swift
//  GizeTransport
//
//  Created by User on 7/22/23.
//
import SwiftUI

struct PickupPassengerView: View {
    let trip: Trip
    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.theme.mutedText.opacity(0.25))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            header
            passengerCard
            guidanceCard
            actionRow
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
        .gizePanel()
        .onAppear {
            viewModel.fetchPassengerPhoneNumber(uid: trip.passengerUid)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Navigate to pickup")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(Color.theme.ink)

            Text(trip.pickupLocationName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.theme.mutedText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var passengerCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 62, height: 62)
                .foregroundColor(Color.theme.darkGreen)

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.passengerName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.theme.ink)

                Text("Passenger waiting for pickup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.theme.mutedText)
            }

            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.theme.darkGreen)

                Button {
                    callPassenger()
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(viewModel.passengerPhoneNumber == nil ? Color.theme.mutedText : Color.theme.darkGreen)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.passengerPhoneNumber == nil)
            }
        }
        .padding(14)
        .background(Color.theme.softSurface)
        .clipShape(RoundedRectangle(cornerRadius: GizeUI.corner, style: .continuous))
    }

    private var guidanceCard: some View {
        HStack(spacing: 12) {
            metric(icon: "clock.fill", title: "ETA", value: "\(trip.travelTimeToPassenger) min")
            metric(icon: "location.fill", title: "Distance", value: trip.distanceToPassenger.distanceInKilometersString())
            metric(icon: "shield.fill", title: "Status", value: "Verified")
        }
    }

    private func metric(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.theme.darkGreen)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.theme.mutedText)

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color.theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.theme.fieldSurface)
        .clipShape(RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous))
    }

    private var actionRow: some View {
        VStack(spacing: 12) {
            SwipeButton(action: {
                AppLogger.info("Driver arrived at pickup.")
                if viewModel.trip?.platform == "IOS" {
                    viewModel.driverArrived()
                } else {
                    viewModel.sendFCMMessageArrived()
                    viewModel.driverArrived()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Swipe when arrived")
                        .font(.headline)
                        .fontWeight(.bold)
                    Image(systemName: "chevron.right")
                }
                .foregroundColor(.white)
            }
            .frame(height: 52)
            .background(Color.theme.darkGreen)
            .cornerRadius(GizeUI.compactCorner)

            Button {
                AppLogger.info("Driver cancelled trip.")
                viewModel.cancelTripAsDriver()
            } label: {
                Text("Cancel trip")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundColor(Color.theme.danger)
                    .background(Color.theme.danger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func callPassenger() {
        guard let phoneNumber = viewModel.passengerPhoneNumber,
              let url = URL(string: "tel://\(phoneNumber)"),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct SwipeButton<Label: View>: View {
    var action: () -> Void
    var label: Label

    @State private var offset: CGFloat = 0

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous)
                    .fill(Color.theme.darkGreen.opacity(0.2))
                    .overlay(
                        Text("Swipe")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.leading, 18),
                        alignment: .leading
                    )

                RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous)
                    .fill(Color.theme.darkGreen)
                    .frame(width: max(offset + 108, 108))

                HStack {
                    label
                        .padding(.leading, 18)
                        .offset(x: max(offset - 18, 0))
                    Spacer()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let maxOffset = max(width - 68, 0)
                        offset = min(max(gesture.translation.width, 0), maxOffset)
                    }
                    .onEnded { _ in
                        let threshold = width * 0.52
                        if offset > threshold {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                offset = max(width - 68, 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                action()
                                offset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                offset = 0
                            }
                        }
                    }
            )
            .animation(.easeInOut, value: offset)
        }
    }
}
