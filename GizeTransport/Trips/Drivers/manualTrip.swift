import SwiftUI
import MapKit
let ethiopiaCenter = CLLocationCoordinate2D(latitude: 9.145, longitude: 40.489673)

// Region span for a broad covering
let ethiopiaRegion = MKCoordinateRegion(
    center: ethiopiaCenter,
    latitudinalMeters: 1000_000, // 1,000 km north-to-south
    longitudinalMeters: 1000_000 // 1,000 km east-to-west
)
struct ManualTripView: View {
    @State private var startLocationText = ""
    @State private var queryFragment: String = ""
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var phoneNumber: String = ""
    var trip: Trip?
    @State private var isLoading = false
    var currentDriver: User?
    var selectedPassenger: User?
    @EnvironmentObject var viewModel: HomeViewModel

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Circle().fill(Color(.systemGray3)).frame(width: 6, height: 6)
                    Rectangle().fill(Color(.systemGray3)).frame(width: 1, height: 24)
                    Circle().fill(Color.black).frame(width: 6, height: 6)
                }
                VStack {
                    TextField(viewModel.trip?.pickupLocationName ?? "Current location", text: $startLocationText)
                        .font(.title2)
                        .frame(height: 40)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)

                    Divider()

                    TextField("Where to?", text: $queryFragment)
                        .onChange(of: queryFragment) { newValue in
                            if !newValue.isEmpty {
                                DispatchQueue.main.async {
                                    self.searchCompleter.queryFragment = newValue
                                }
                            }
                        }
                        .font(.title2)
                        .frame(height: 40)
                        .background(Color(.systemGray4))
                        .cornerRadius(20)
                    Divider()

                    TextField("Enter Phone Number", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .font(.title2)
                        .frame(height: 40)
                        .background(Color(.systemGray5))
                        .cornerRadius(20)
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.searchResults, id: \.self) { result in
                        VStack(alignment: .leading) {
                            Text(result.title).bold()
                            Text(result.subtitle).foregroundColor(.gray)
                        }
                        .font(.system(size: 23))
                        .foregroundColor(.gray)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.queryFragment = "\(result.title), \(result.subtitle)"
                                viewModel.searchResults = []
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            Button(action: {
                if let trip = self.trip {
                    AppLogger.info("Starting a manual trip.")
                    self.isLoading = true
                    viewModel.startManualTrip(withPassengerUid: trip.passengerUid)
                    viewModel.sendFCMNotificationForManual()
                    if let token = selectedPassenger?.fcmToken, !token.isEmpty {
                        viewModel.sendFCMMessageManualTrip(with: token)
                    } else {
                        AppLogger.warning("Manual trip passenger FCM token is missing.")
                    }
                } else {
                    self.isLoading = false
                    AppLogger.warning("No manual trip details are available.")
                }
            }, label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Start Trip")
                }
            })
            .padding()
            .background(Color.darkGreen)
            .foregroundColor(.white)
            .cornerRadius(8)
            .disabled(isLoading)
        }
        .padding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.backgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.theme.secondaryBackgroundColor, radius: 20)
        .onAppear {
            setupSearchCompleter()
        }
    }

    private func setupSearchCompleter() {
        searchCompleter.delegate = viewModel
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        searchCompleter.region = ethiopiaRegion
    }
}

struct PlaceholderTextField: View {
    var title: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(.leading, 4)
            }
            if isSecure {
                SecureField(title, text: $text)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            } else {
                TextField(title, text: $text)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
        }
    }
}
//extension UIApplication {
//    func endEditing(_ force: Bool) {
//        self.windows
//            .filter{$0.isKeyWindow}
//            .first?
//            .endEditing(force)
//    }
//}
