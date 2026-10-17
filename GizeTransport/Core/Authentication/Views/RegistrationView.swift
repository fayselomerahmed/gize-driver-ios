import SwiftUI
import CoreLocation
import FirebaseFirestore

struct RegistrationView: View {
    @StateObject var viewModel = AuthViewModel()
    @StateObject private var locationManager = LocationManager()  // Correctly initialized as a StateObject
    @State private var fullName: String = ""
    @State private var phoneNumber: String = "+251"
    @State private var showingOTPView = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var email = ""

    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                    .padding(.top, 40)

                VStack(spacing: 30) {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.all)

                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                    HStack {
                        Image("ethiopian_flag") // Use an image asset for the flag
                            .resizable()
                            .frame(width: 30, height: 20)
                            .padding(.leading, 16)
                        TextField("Phone", text: $phoneNumber)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.trailing, 16)
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 20)

                Button(action: registerAndSendOTP) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("REGISTER")
                                .foregroundColor(.white)
                                .bold()
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color.darkGreen)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()

                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.gray)
                    NavigationLink(destination: LoginView(viewModel: viewModel)) {
                        Text("Login")
                            .foregroundColor(.darkGreen)
                            .underline()
                    }
                }
                .padding(.bottom, 16)
            }
            .navigationTitle("Register")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Registration"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $showingOTPView) {
                let coordinates = locationManager.userLocation.map { GeoPoint(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
                    ?? GeoPoint(latitude: 0, longitude: 0) // Provide a default GeoPoint if userLocation is nil

                OTPVerificationView(
                    phoneNumber: phoneNumber,
                    coordinates: coordinates,
                    fullName: fullName,
                    email: email,
                    isRegistration: true, viewModel: viewModel
                )
            }
        }
    }

    private func registerAndSendOTP() {
        isLoading = true
        if let location = locationManager.userLocation {
            _ = GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            viewModel.registerUser(phoneNumber: phoneNumber, fullName: fullName, accountType: .driver) { success in
                isLoading = false
                if success {
                    showingOTPView = true
                } else {
                    alertMessage = "Registration failed. Please try again."
                    showAlert = true
                }
            }
        } else {
            isLoading = false
            alertMessage = "Location not available"
            showAlert = true
        }
    }
}
