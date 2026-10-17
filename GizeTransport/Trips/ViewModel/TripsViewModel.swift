//
//  TripViewModel.swift
//  UberSwiftUI
//
//  Created by Stephan Dowless on 9/2/22.
//

import FirebaseFirestore
import FirebaseAuth

class TripViewModel {
    // Assuming `trips` is a property in your class
    var trips: [Trip] = []

    func fetchTrips() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Assuming 'users' is the root collection where user documents are stored
        let usersCollection = Firestore.firestore().collection("users")

        // Access the "user-trips" collection for the current user
        usersCollection.document(uid).collection("user-trips").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                // Handle the error or return if there are no documents
                if let error = error {
                    print("Error fetching documents: \(error.localizedDescription)")
                }
                return
            }

            // Use compactMap to convert the documents to Trip objects
            let results = documents.compactMap { try? $0.data(as: Trip.self) }

            // Update the trips property with the results
            self.trips = results
        }
    }
}
