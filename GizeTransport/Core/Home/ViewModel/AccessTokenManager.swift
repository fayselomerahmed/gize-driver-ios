//
//  AccessTokenManager.swift
//  GizeDriver
//
//  Created by User on 10/24/24.
//

import Foundation
import FirebaseFirestore
import FirebaseMessaging

// MARK: - FCMNotificationManager
class FCMNotificationManager {
    // Singleton Instance
    static let shared = FCMNotificationManager()
    let db = Firestore.firestore()
    
    init() {}
    
    /// Sends a message to a specific passenger by passengerId
    func sendMessageToPassenger(passengerId: String, title: String, body: String) {
        // Retrieve the passenger's FCM token from Firestore
        db.collection("users").document(passengerId).getDocument { [weak self] (document, error) in
            if let error = error {
                print("Error fetching passenger document: \(error)")
                return
            }
            
            if let document = document {
                if !document.exists {
                    print("Passenger document does not exist.")
                    return
                }
                
                if let data = document.data(), let fcmToken = data["fcmToken"] as? String {
                    // If we reach this point, everything is correct
                    AppLogger.info("Retrieved FCM token for passenger.")
                    // Write a new message to Firestore
                    let messageData: [String: Any] = [
                        "passengerId": passengerId,
                        "title": title,
                        "body": body,
                        "timestamp": Timestamp()
                    ]
                    
                    self?.db.collection("messages").addDocument(data: messageData) { error in
                        if let error = error {
                            print("Error adding message document: \(error)")
                        } else {
                            print("Message successfully added to Firestore. Sending notification request to server...")
                            self?.sendNotificationRequestToServer(fcmToken: fcmToken, title: title, body: body)
                        }
                    }
                } else {
                    print("Passenger notification token is unavailable.")
                }
            } else {
                print("Passenger document is unavailable.")
            }
        }
    }
    
    /// Sends a notification request to the Cloud Function server (already implemented in your code)
    func sendNotificationRequestToServer(fcmToken: String, title: String, body: String) {
        guard let url = URL(string: AppConfig.notificationProxyURL) else {
            print("Invalid server URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = AppConfig.notificationApiKey { request.setValue(apiKey, forHTTPHeaderField: "x-api-key") } // Add API Key

        // Include default notification sound in the payload
        let payload: [String: Any] = [
            "fcmToken": fcmToken,
            "title": title,
            "body": body,
            "notification": [
                "title": title,
                "body": body,
                "sound": "default" // This line is crucial to enable default notification sound
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("Error serializing JSON: \(error.localizedDescription)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error sending notification request: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("Notification sent successfully.")
                } else {
                    print("Failed to send notification request to server. HTTP Status Code: \(httpResponse.statusCode)")
                }
            }
        }
        task.resume()
    }

}
