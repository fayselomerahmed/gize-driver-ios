//
//  AuthViewModel.swift
//  GizeTransport
//
//  Created by User on 3/30/23.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseDatabase
import Combine
import FirebaseFirestoreSwift
import SwiftUI
import FirebaseMessaging

class AuthViewModel: ObservableObject {
    weak var viewController: UIViewController?
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isLoggingIn: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private let service = UserService.shared
    @Published var isAuthenticated = false
    @Published var user: User?
    var authChanges = PassthroughSubject<Bool, Never>()

    init() {
        userSession = Auth.auth().currentUser
        fetchUser()
        setupAuthListener()
        requestFCMToken()
    }
    
    func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.userSession = user
                self.authChanges.send(user != nil)
                if let user = user {
                    self.fetchUserDetails(firebaseUser: user)
                } else {
                    self.currentUser = nil
                }
            }
        }
    }

    func fetchUserDetails(firebaseUser: FirebaseAuth.User?) {
        guard let firebaseUser = firebaseUser else {
            self.currentUser = nil
            return
        }

        let db = Firestore.firestore()
        let docRef = db.collection("users").document(firebaseUser.uid)

        docRef.getDocument { [weak self] (document, error) in
            if let error = error {
                self?.showAlert(message: "Error fetching user details: \(error.localizedDescription)")
                self?.currentUser = nil
                return
            }
            guard let document = document, document.exists else {
                self?.showAlert(message: "User document does not exist.")
                self?.currentUser = nil
                return
            }
            do {
                self?.currentUser = try document.data(as: User.self)
                self?.updateFCMToken()
            } catch {
                self?.showAlert(message: "Error decoding user: \(error.localizedDescription)")
                self?.currentUser = nil
            }
        }
    }

    func signInWithPhoneNumber(_ phoneNumber: String) {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] (verificationID, error) in
            if let error = error {
                self?.showAlert(message: "Verification error: \(error.localizedDescription)")
                return
            }
            UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
            self?.showAlert(message: "Verification code sent successfully.")
            self?.fetchUser()
        }
    }

    func verifyPhoneNumber(verificationCode: String, completion: @escaping (Bool) -> Void) {
        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
            showAlert(message: "Verification ID not found.")
            return
        }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
            if let error = error {
                self?.showAlert(message: "Error signing in: \(error.localizedDescription)")
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.isAuthenticated = true
                completion(true)
            }
            self?.userSession = authResult?.user
            self?.fetchUser()
            self?.initializeWalletForUser(uid: authResult?.user.uid ?? "")
        }
    }

    func sendVerificationCode(toPhoneNumber phoneNumber: String, completion: @escaping (Error?) -> Void) {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
            if let error = error {
                completion(error)
                return
            }
            UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
            completion(nil)
        }
    }

    func registerUser(phoneNumber: String, fullName: String, accountType: AccountType, completion: @escaping (Bool) -> Void) {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            if let error = error {
                self?.showAlert(message: "Phone verification failed: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let verificationID = verificationID {
                UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                UserDefaults.standard.set(fullName, forKey: "pendingFullName")
                UserDefaults.standard.set(accountType.rawValue, forKey: "pendingAccountType")
                self?.showAlert(message: "Verification code sent to your phone.")
                completion(true)
            } else {
                self?.showAlert(message: "Failed to obtain verification ID.")
                completion(false)
            }
        }
    }

    func verifyRegistration(verificationCode: String, coordinates: GeoPoint, fullName: String, email: String) {
        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
            showAlert(message: "Verification ID not found. Please start over the registration process.")
            return
        }

        let credential = PhoneAuthProvider.provider().credential(withVerificationID: verificationID, verificationCode: verificationCode)
        
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                self?.showAlert(message: "Failed to register user: \(error.localizedDescription)")
                return
            }
            guard let user = authResult?.user else {
                self?.showAlert(message: "User data not available after authentication.")
                return
            }
            
            let newUser = User(
                fullname: fullName,
                email: email,
                uid: user.uid,
                coordinates: coordinates,
                accountType: .driver,
                isActive: true,
                phonenumber: user.phoneNumber,
                profileImageUrl : "https://example.invalid/default-avatar.png"
            )
            do {
                try Firestore.firestore().collection("users").document(user.uid).setData(from: newUser)
                
                let dbRef = Database.database().reference()
                dbRef.child("DriverInfo").child(user.uid).setValue([
                    "avatars": "https://example.invalid/default-avatar.png",
                    "firstname": fullName,
                    "CC": 0,
                    "rating": 3,
                    "email": email,
                    "lastname": fullName,
                    "platform": "IOS",
                    "Status": "Pending",
                    "phonenumber": user.phoneNumber ?? ""
                ]) { error, _ in
                    if let error = error {
                        self?.showAlert(message: "Error saving user to Realtime Database: \(error.localizedDescription)")
                    } else {
                        self?.showAlert(message: "User successfully saved to Realtime Database")
                        self?.initializeWalletForUser(uid: user.uid)
                        self?.updateFCMToken()
                    }
                }
            } catch {
                self?.showAlert(message: "Error saving user to Firestore: \(error.localizedDescription)")
            }
        }
    }

    func requestFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                self?.showAlert(message: "Error fetching FCM token: \(error.localizedDescription)")
            } else if let token = token {
                self?.saveFCMToken(token)
            }
        }
    }

    func saveFCMToken(_ token: String) {
        guard let driverUid = Auth.auth().currentUser?.uid else { return }
        let dbRef = Database.database().reference().child("Token").child(driverUid)
        dbRef.updateChildValues(["fcmToken": token]) { error, _ in
            if let error = error {
                self.showAlert(message: "Error saving FCM token to Realtime Database: \(error.localizedDescription)")
            } else {
                self.showAlert(message: "FCM token successfully saved to Realtime Database")
            }
        }
    }

    func updateFCMToken() {
        Messaging.messaging().token { [weak self] token, error in
            if let error = error {
                self?.showAlert(message: "Error fetching FCM token: \(error.localizedDescription)")
            } else if let token = token {
                self?.saveFCMToken(token)
            }
        }
    }

    func initializeWalletForUser(uid: String) {
        let realtimeDbRef = Database.database().reference().child("Wallet").child(uid)
        realtimeDbRef.observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists(), let walletBalance = snapshot.value as? Double {
                print("Wallet already exists with balance: \(walletBalance)")
                Firestore.firestore().collection("users").document(uid).updateData(["wallet": walletBalance]) { error in
                    if let error = error {
                        self.showAlert(message: "Error updating wallet balance in Firestore: \(error.localizedDescription)")
                    } else {
                        print("Wallet balance successfully updated in Firestore")
                    }
                }
            } else {
                print("Wallet does not exist, creating a new one")
                realtimeDbRef.setValue(0.0) { error, _ in
                    if let error = error {
                        self.showAlert(message: "Error initializing wallet in Realtime Database: \(error.localizedDescription)")
                    } else {
                        print("Wallet successfully initialized in Realtime Database")
                    }
                }
                Firestore.firestore().collection("users").document(uid).updateData(["wallet": 0.0]) { error in
                    if let error = error {
                        self.showAlert(message: "Error initializing wallet in Firestore: \(error.localizedDescription)")
                    } else {
                        print("Wallet successfully initialized in Firestore")
                    }
                }
            }
        }
    }

    func showAlert(message: String) {
        guard let viewController = viewController else { return }
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        DispatchQueue.main.async {
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    func signout() {
        guard let user = Auth.auth().currentUser else {
            return
        }

        do {
            // Remove driver location
            LocationManager.shared.removeDriverLocation(driverUid: user.uid)

            // Sign out from Firebase Auth
            try Auth.auth().signOut()
            self.userSession = nil
            self.isAuthenticated = false
            self.currentUser = nil
        } catch let signOutError as NSError {
            self.showAlert(message: "Error signing out: \(signOutError.localizedDescription)")
        }
    }

    func fetchUser() {
        service.$user
            .sink { completion in
                switch completion {
                case .finished:
                    print("User data retrieval completed successfully.")
                case let .failure(error):
                    self.showAlert(message: "Error fetching user: \(error.localizedDescription)")
                }
            } receiveValue: { [weak self] user in
                self?.currentUser = user
            }
            .store(in: &cancellables)
    }
}
