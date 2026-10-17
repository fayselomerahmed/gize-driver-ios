//
//  TripHistoryView.swift
//  GizeDriver
//
//  Created by User on 10/7/23.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TripHistoryView: View {
    @State private var trips: [Trip] = []
    @State private var jobsCompleted: Int = 0
    @State private var totalEarnings: Double = 0.0
    @EnvironmentObject var homeViewModel: HomeViewModel
    @State private var selectedDateFilter: DateFilter = .today
    @State private var selectedTab: TabFilter = .day
    @State private var selectedWeekFilter: WeekFilter = .lastSevenDays

    var body: some View {
        NavigationView {
            VStack {
                // Header Section
                HStack {
                    Button(action: {
                        // Action for back button
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Earnings")
                        .foregroundColor(.white)
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        // Action for tax button
                    }) {
                        // Placeholder for TAX button
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.darkGreen)

                // Tab Picker Section
                Picker("Filter", selection: $selectedTab) {
                    Text("Day").tag(TabFilter.day)
                    Text("Week").tag(TabFilter.week)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if selectedTab == .day {
                    // Date Picker Section for Day
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(DateFilter.allCases, id: \.self) { filter in
                                DateFilterView(filter: filter, isSelected: filter == selectedDateFilter)
                                    .onTapGesture {
                                        selectedDateFilter = filter
                                        loadUserTrips(for: filter)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 5)
                    .background(Color.darkGreen)
                    
                    // Summary Section
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total earnings")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("ETB \(totalEarnings, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Jobs completed")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("\(jobsCompleted)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                    
                    // List of Trips
                    List(trips) { trip in
                        VStack(alignment: .leading) {
                            Text(trip.pickupLocationName)
                                .font(.headline)
                            Text(trip.dropofflocationName)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            HStack {
                                if let tripDate = trip.tripDate {
                                    Text(tripDate.localFormatted(date: .omitted, time: .shortened))
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("ETB \(trip.tripCost, specifier: "%.2f")")
                                    .font(.footnote)
                                    .foregroundColor(.darkGreen)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(InsetGroupedListStyle())
                    .navigationTitle("Earnings")
                    .onAppear {
                        loadUserTrips(for: selectedDateFilter)
                    }
                } else if selectedTab == .week {
                    // Week Filter Section
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(WeekFilter.allCases, id: \.self) { filter in
                                WeekFilterView(filter: filter, isSelected: filter == selectedWeekFilter)
                                    .onTapGesture {
                                        selectedWeekFilter = filter
                                        loadUserTrips(for: filter)
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 5)
                    .background(Color.darkGreen)
                    
                    // Summary Section
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total earnings")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("ETB \(totalEarnings, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Jobs completed")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Text("\(jobsCompleted)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 1)
                    .padding(.horizontal)
                    
                    // List of Trips
                    List(trips) { trip in
                        VStack(alignment: .leading) {
                            Text(trip.pickupLocationName)
                                .font(.headline)
                            Text(trip.dropofflocationName)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            HStack {
                                if let tripDate = trip.tripDate {
                                    Text(tripDate.localFormatted(date: .omitted, time: .shortened))
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("ETB \(trip.tripCost, specifier: "%.2f")")
                                    .font(.footnote)
                                    .foregroundColor(.darkGreen)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(InsetGroupedListStyle())
                    .navigationTitle("Trip History")
                    .onAppear {
                        loadUserTrips(for: selectedWeekFilter)
                    }
                }
            }
            .background(Color(.darkGreen))
        }
        .onAppear {
            loadUserTrips(for: .today)
        }
    }

    func loadUserTrips(for filter: DateFilter) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated.")
            return
        }

        let startDate = Calendar.current.startOfDay(for: filter.date)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)!

        print("Loading trips from \(startDate) to \(endDate)")
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-trips")
            .whereField("tripDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("tripDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error fetching documents: \(error)")
                } else {
                    let trips = querySnapshot?.documents.compactMap { document -> Trip? in
                        try? document.data(as: Trip.self)
                    } ?? []
                    print("Fetched \(trips.count) trips")
                    DispatchQueue.main.async {
                        self.trips = trips
                        self.jobsCompleted = trips.count
                        self.totalEarnings = trips.reduce(0) { $0 + $1.tripCost }
                    }
                }
            }
    }

    func loadUserTrips(for filter: WeekFilter) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("User not authenticated.")
            return
        }

        let startDate = filter.dateRange.startDate
        let endDate = filter.dateRange.endDate

        print("Loading trips from \(startDate) to \(endDate)")
        
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-trips")
            .whereField("tripDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("tripDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error fetching documents: \(error)")
                } else {
                    let trips = querySnapshot?.documents.compactMap { document -> Trip? in
                        try? document.data(as: Trip.self)
                    } ?? []
                    print("Fetched \(trips.count) trips")
                    DispatchQueue.main.async {
                        self.trips = trips
                        self.jobsCompleted = trips.count
                        self.totalEarnings = trips.reduce(0) { $0 + $1.tripCost }
                    }
                }
            }
    }
}

struct DateFilterView: View {
    let filter: DateFilter
    let isSelected: Bool

    var body: some View {
        VStack {
            Text(filter.dayOfWeek)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .black)
            Text(filter.dateString)
                .font(.footnote)
                .foregroundColor(isSelected ? .white : .gray)
        }
        .padding()
        .background(isSelected ? Color.white : Color.clear)
        .cornerRadius(10)
    }
}

struct WeekFilterView: View {
    let filter: WeekFilter
    let isSelected: Bool

    var body: some View {
        VStack {
            Text(filter.weekString)
                .font(.headline)
                .foregroundColor(isSelected ? .black : .black)
        }
        .padding()
        .background(isSelected ? Color.white : Color.clear)
        .cornerRadius(10)
    }
}

enum TabFilter: String {
    case day
    case week
}

enum DateFilter: Hashable, CaseIterable {
    case today
    case yesterday
    case twoDaysAgo
    case threeDaysAgo
    case fourDaysAgo
    case fiveDaysAgo
    case sixDaysAgo
    case sevenDaysAgo

    var date: Date {
        switch self {
        case .today: return Date()
        case .yesterday: return Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        case .twoDaysAgo: return Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        case .threeDaysAgo: return Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        case .fourDaysAgo: return Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        case .fiveDaysAgo: return Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        case .sixDaysAgo: return Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        case .sevenDaysAgo: return Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self.date)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: self.date)
    }

    static var allCases: [DateFilter] {
        return [
            .sevenDaysAgo,
            .sixDaysAgo,
            .fiveDaysAgo,
            .fourDaysAgo,
            .threeDaysAgo,
            .twoDaysAgo,
            .yesterday,
            .today
        ]
    }
}

enum WeekFilter: Hashable, CaseIterable {
    case lastSevenDays

    var dateRange: (startDate: Date, endDate: Date) {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(byAdding: .day, value: -6, to: today)!
        return (startDate: startOfWeek, endDate: today)
    }

    var weekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startDateString = formatter.string(from: self.dateRange.startDate)
        let endDateString = formatter.string(from: self.dateRange.endDate)
        return "\(startDateString) - \(endDateString)"
    }

    static var allCases: [WeekFilter] {
        return [
            .lastSevenDays
        ]
    }
}


