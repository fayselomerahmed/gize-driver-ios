//
//  LogInView.swift
//  GizeTransport
//
//  Created by User on 3/28/23.
//
import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var phoneNumber: String = "+251"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var showingOTPView = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.softSurface.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        header
                        formCard
                        legalCopy
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 36)
                    .padding(.bottom, 28)
                }

                if isLoading {
                    LoadingView(isLoading: $isLoading)
                        .transition(.opacity)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Driver login"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .sheet(isPresented: $showingOTPView) {
            OTPVerificationView(phoneNumber: phoneNumber, viewModel: viewModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: GizeUI.softShadow, radius: 14, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Drive with Gize")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color.theme.ink)
                Text("Go online, receive trips, and manage earnings from one focused driver workspace.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.theme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var formCard: some View {
        VStack(spacing: 18) {
            phoneNumberField
            Button("Continue") {
                sendCode()
            }
            .buttonStyle(GizePrimaryButtonStyle())

            NavigationLink(destination: RegistrationView()) {
                Text("Register as driver")
            }
            .buttonStyle(GizeSecondaryButtonStyle())
        }
        .padding(18)
        .gizePanel()
    }

    private var phoneNumberField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mobile number")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.theme.mutedText)

            HStack(spacing: 12) {
                Image("ethiopian_flag")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                TextField("Phone no.", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(Color.theme.fieldSurface)
            .clipShape(RoundedRectangle(cornerRadius: GizeUI.compactCorner, style: .continuous))
        }
    }

    private var legalCopy: some View {
        Text("By continuing, you agree to Gize Terms & Conditions and Privacy Policy.")
            .font(.footnote)
            .foregroundColor(Color.theme.mutedText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }

    private func sendCode() {
        isLoading = true
        viewModel.sendVerificationCode(toPhoneNumber: phoneNumber) { error in
            isLoading = false
            if let error = error {
                alertMessage = "Failed to send verification code: \(error.localizedDescription)"
                showAlert = true
            } else {
                showingOTPView = true
            }
        }
    }
}

import SwiftUI
import FirebaseFirestore

struct OTPVerificationView: View {
    var phoneNumber: String
    var coordinates: GeoPoint? = nil
    var fullName: String? = nil
    var email: String? = nil
    var isRegistration: Bool = false
    
    @State private var otpCode: String = ""
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var remainingTime = 900 // 15 minutes countdown
    @State private var timer: Timer? = nil
    @FocusState private var focusedField: OTPField?

    enum OTPField: Int, CaseIterable {
        case field1, field2, field3, field4, field5, field6
    }

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Try again in \(remainingTime / 60)m \(remainingTime % 60)s")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()

            Spacer()

            Text("Code sent via SMS, WhatsApp, or Viber to")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
            
            Text(phoneNumber)
                .font(.title2)
                .foregroundColor(.yellow)
                .padding(.bottom, 20)

            HStack(spacing: 10) {
                ForEach(OTPField.allCases, id: \.rawValue) { field in
                    TextField("", text: binding(for: field))
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50, height: 50)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: field)
                        .onChange(of: binding(for: field).wrappedValue) { newValue in
                            if newValue.count == 1 {
                                if field.rawValue < OTPField.allCases.count - 1 {
                                    focusedField = OTPField(rawValue: field.rawValue + 1)
                                } else {
                                    focusedField = nil
                                }
                            }
                        }
                }
            }
            .padding(.bottom, 20)

            Button(action: verifyOTP) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Verify")
                            .foregroundColor(.white)
                            .bold()
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Verification"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .disabled(otpCode.count < 6)

            Spacer()
        }
        .padding()
        .navigationTitle("Enter OTP")
        .onAppear {
            sendOTP()
            startTimer()
        }
    }

    private func sendOTP() {
        viewModel.sendVerificationCode(toPhoneNumber: phoneNumber) { error in
            if let error = error {
                alertMessage = "Failed to send OTP: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    private func verifyOTP() {
        isLoading = true
        if isRegistration, let coordinates = coordinates, let fullName = fullName, let email = email {
            viewModel.verifyRegistration(verificationCode: otpCode, coordinates: coordinates, fullName: fullName, email: email)
            alertMessage = "Verification successful"
            showAlert = true
            isLoading = false
            presentationMode.wrappedValue.dismiss()
        } else {
            viewModel.verifyPhoneNumber(verificationCode: otpCode) { success in
                isLoading = false
                if success {
                    alertMessage = "Verification successful"
                    showAlert = true
                    presentationMode.wrappedValue.dismiss()
                } else {
                    alertMessage = "Verification failed. Please try again."
                    showAlert = true
                }
            }
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func binding(for field: OTPField) -> Binding<String> {
        let index = field.rawValue
        return Binding<String>(
            get: {
                if otpCode.count > index {
                    let startIndex = otpCode.index(otpCode.startIndex, offsetBy: index)
                    let endIndex = otpCode.index(startIndex, offsetBy: 1)
                    return String(otpCode[startIndex..<endIndex])
                }
                return ""
            },
            set: { newValue in
                if newValue.count <= 1 {
                    if otpCode.count > index {
                        otpCode.remove(at: otpCode.index(otpCode.startIndex, offsetBy: index))
                    }
                    if !newValue.isEmpty {
                        otpCode.insert(contentsOf: newValue, at: otpCode.index(otpCode.startIndex, offsetBy: index))
                    }
                }
            }
        )
    }
}
