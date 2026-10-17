//
//  UserViewModel.swift
//  GizeDriver
//
//  Created by User on 4/29/24.
//
import FirebaseFirestore
import FirebaseFirestoreSwift
import Combine

class UserViewModel: ObservableObject {
    @Published var passenger: Passenger?
    @Published var errorMessage: String?

    var onPassengerFetched: ((Passenger) -> Void)?

    func getPassengerByPhoneNumber(_ phoneNumber: String) {
        let normalizedPhoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPhoneNumber.isEmpty else {
            self.errorMessage = "Phone number cannot be empty."
            return
        }

        fetchPassengerByPhoneNumber(phoneNumber: normalizedPhoneNumber) { passenger, error in
            DispatchQueue.main.async {
                if let passenger = passenger {
                    self.passenger = passenger
                    self.onPassengerFetched?(passenger)
                    AppLogger.info("Passenger record fetched.")
                } else if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    print("Error fetching passenger: \(error.localizedDescription)")
                } else {
                    self.errorMessage = "No registered passenger was found. Creating passenger records is disabled in this prototype."
                }
            }
        }
    }

    private func fetchPassengerByPhoneNumber(phoneNumber: String, completion: @escaping (Passenger?, Error?) -> Void) {
        let db = Firestore.firestore()
        let usersRef = db.collection("users")

        usersRef.whereField("phonenumber", isEqualTo: phoneNumber).getDocuments { (querySnapshot, error) in
            if let error = error {
                completion(nil, error)
            } else {
                guard let document = querySnapshot?.documents.first else {
                    completion(nil, nil)
                    return
                }
                do {
                    let passenger = try document.data(as: Passenger.self)
                    completion(passenger, nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
    }
}

