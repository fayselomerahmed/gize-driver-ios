//
//  HomeView.swift
//  UberSwiftUitutorial
//
//  Created by User on 11/15/22.
//

import SwiftUI
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

struct HomeView: View {
    @State private var mapState = MapViewState.noInput
    @State private var isShowSideMenu = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var homeViewModel: HomeViewModel
    @StateObject private var locationManager = LocationManager.shared // Ensure LocationManager is a singleton or ObservableObject

    @State private var userLocation: CLLocation?
    @State var isActiveDriver = false
    @State var isShowPopUp = true
    @State var isShowManualTrip = false
    @State var isShowTripCompleted = false  // New state variable for TripCompletedView
    @State var user: User?
    @State private var todaysEarnings: Double = 0.0 // <-- Uncommented and added this line

    var body: some View {
        Group {
            if authViewModel.userSession == nil {
                if #available(iOS 16.0, *) {
                    LoginView(viewModel: authViewModel).environmentObject(authViewModel)
                } else {
                    // Fallback for earlier versions
                    LoginView(viewModel: authViewModel).environmentObject(authViewModel)
                }
            } else if let user = authViewModel.currentUser {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        mainContent(user: user)
                    }
                } else {
                    NavigationView {
                        mainContent(user: user)
                    }
                }
            }
        }
        .onAppear {
            fetchTodaysEarnings()
        }
    }

    @ViewBuilder
    private func mainContent(user: User) -> some View {
        ZStack {
            if isShowSideMenu {
                if #available(iOS 16.0, *) {
                    SideMenuView(user: user)
                } else {
                    // Fallback on earlier versions
                }
            }
            if #available(iOS 16.0, *) {
                mapView
                    .offset(x: isShowSideMenu ? 250 : 0)
                    .shadow(color: isShowSideMenu ? .black : .clear, radius: 10)
            } else {
                // Fallback on earlier versions
            }
            if isShowSideMenu {
                Color.black.opacity(0.01)
                    .edgesIgnoringSafeArea(.all)
                    .offset(x: 250)
                    .onTapGesture {
                        withAnimation {
                            isShowSideMenu = false
                        }
                    }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            self.isActiveDriver = true
            isShowSideMenu = false
            locationManager.startUpdatingLocation()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
    }
}

extension HomeView {

    @available(iOS 16.0, *)
    var mapView: some View {
        mapViewContent
    }

    private var mapViewContent: some View {
        ZStack(alignment: .bottom) {
            UberMapViewRepresentable(mapState: $mapState)
                .ignoresSafeArea()
                .onTapGesture {
                    self.isShowSideMenu = false
                    AppLogger.info("Map tapped.")
                }

            VStack(spacing: 0) {
                driverStatusBar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                Spacer()

                HStack {
                    Spacer()
                    quickActionRail
                        .padding(.trailing, 16)
                }

                EarningsView(todaysEarnings: $todaysEarnings)
                    .environmentObject(homeViewModel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 22)
            }

            if let user = authViewModel.currentUser {
                homeViewModel.viewForState(mapState, user: user)
                    .transition(.move(edge: .bottom))
            }

            if let trip = homeViewModel.trip {
                switch trip.state {
                case .requested:
                    if homeViewModel.trip?.tripType == .preorder {
                        AcceptPreOrderTripView(trip: trip)
                    } else {
                        AcceptTripView(trip: trip)
                            .transition(.move(edge: .bottom))
                    }
                case .accepted:
                    if homeViewModel.trip?.tripType == .preorder {
                        PreorderSuccessfulView(showingPopup: $isShowPopUp)
                            .transition(.move(edge: .bottom))
                    } else {
                        PickupPassengerView(trip: trip)
                            .transition(.move(edge: .bottom))
                    }
                case .arrived:
                    ArrivalAtPassengerView(trip: trip)
                        .transition(.move(edge: .bottom))
                case .starttrip:
                    TripStartedView(trip: trip)
                        .transition(.move(edge: .bottom))
                case .tripCompleted:
                    if homeViewModel.isShowTripCompleted {
                        TripCompletedView(trip: trip, isPresented: $homeViewModel.isShowTripCompleted)
                    }
                default:
                    EmptyView()
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onReceive(LocationManager.shared.$userLocation) { location in
            if let location = location {
                homeViewModel.userLocation = location.coordinate
            }
        }
        .onReceive(homeViewModel.$selectedUberLocation) { location in
            if location != nil {
                self.mapState = .locationSelected
            }
        }
        .onReceive(homeViewModel.$trip) { trip in
            guard let trip = trip else {
                self.mapState = .noInput
                return
            }
            withAnimation(.spring()) {
                switch trip.state {
                case .requested:
                    self.mapState = .tripRequested
                    isShowSideMenu = false
                    isShowManualTrip = false
                case .rejected:
                    self.mapState = .tripRejected
                case .accepted:
                    self.mapState = .tripAccepted
                    isShowSideMenu = false
                    isActiveDriver = false
                case .passengerCancelled:
                    self.mapState = .tripCancelledByPassenger
                    isActiveDriver = true
                case .driverCancelled:
                    self.mapState = .tripCancelledByDriver
                    isActiveDriver = true
                case .arrived:
                    isActiveDriver = false
                    isShowSideMenu = false
                    self.mapState = .tripArrived
                case .noTrip:
                    self.mapState = .noInput
                case .preorder:
                    self.mapState = .preordered
                    isShowSideMenu = false
                case .starttrip:
                    isActiveDriver = false
                    self.isShowSideMenu = false
                    self.mapState = .tripStarted
                    isShowManualTrip = false
                case .tripCompleted:
                    self.mapState = .tripCompleted
                    fetchTodaysEarnings()
                    isActiveDriver = true
                    self.isShowTripCompleted = true // Show TripCompletedView when trip is completed
                }
            }
        }
    }

    private var driverStatusBar: some View {
        HStack(spacing: 12) {
            MapViewActionButton(mapState: $mapState, showSideMenu: $isShowSideMenu)
                .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 3) {
                Text(isActiveDriver ? "Online and accepting trips" : "Offline")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.theme.ink)

                Text(isActiveDriver ? "Your location is visible to nearby passengers." : "Turn on when you are ready to drive.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.theme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isActiveDriver)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color.theme.darkGreen))
                .onChange(of: isActiveDriver) { newValue in
                    homeViewModel.updateActiveStatus(newValue)
                    if !newValue {
                        homeViewModel.deleteDriverLocation()
                    }
                }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: GizeUI.corner, style: .continuous))
        .shadow(color: GizeUI.softShadow, radius: 14, x: 0, y: 7)
    }

    private var quickActionRail: some View {
        VStack(spacing: 14) {
            Button {
                mapState = .manualTrip
                isShowManualTrip = true
            } label: {
                Image(systemName: "figure.wave.circle.fill")
                    .gizeFloatingIcon()
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $isShowManualTrip) {
                if #available(iOS 16.0, *) {
                    LocationSearchView()
                        .presentationDetents([.large])
                } else {
                    LocationSearchView()
                }
            }

            Button {
                homeViewModel.emergencyCall()
            } label: {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color.theme.danger)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                    .shadow(color: GizeUI.softShadow, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func fetchTodaysEarnings() {
        guard let uid = Auth.auth().currentUser?.uid else {
            AppLogger.warning("User not authenticated.")
            return
        }

        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-trips")
            .whereField("tripDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("tripDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments { querySnapshot, error in
                if let error = error {
                    AppLogger.error("Error fetching documents: \(error.localizedDescription)")
                } else {
                    let trips = querySnapshot?.documents.compactMap { document -> Trip? in
                        try? document.data(as: Trip.self)
                    } ?? []
                    AppLogger.info("Fetched today trips.")
                    DispatchQueue.main.async {
                        self.todaysEarnings = trips.reduce(0) { $0 + $1.tripCost } // <-- Corrected variable name
                    }
                }
            }
    }
}

