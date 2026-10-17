//
//  User.swift
//  GizeTransport
//
//  Created by User on 4/2/23.
//

import FirebaseFirestoreSwift
import Firebase

enum AccountType: Int, Codable {
    case passenger
    case driver
}
struct User: Codable {
    @DocumentID var id: String? // Managed by Firestore when fetching data
    var fullname: String
    var email: String
    let uid: String
    var coordinates: GeoPoint
    var accountType: AccountType = .driver
    var homeLocation: SavedLocation?
    var workLocation: SavedLocation?
    var isActive: Bool?
    var phonenumber: String?
    var wallet: Double? = 0
    var cancellationCount : Int? = 0
    var Rating : Int? = 3
    var platform : String? = "IOS"
    var status: String = "Pending"
    var profileImageUrl: String = ""
    var fcmToken : String? 
    var distanceTraveled: Double?
}
 
import FirebaseFirestoreSwift

struct Passenger: Codable, Identifiable {
    @DocumentID var id: String?
    var fullname: String
    var phonenumber: String
    var fcmToken: String
    var coordinates: GeoPoint
    var platform: String

    // Custom initializer if needed
    init(id: String? = nil, fullname: String, phonenumber: String, fcmToken: String, coordinates: GeoPoint, platform: String) {
        self.id = id
        self.fullname = fullname
        self.phonenumber = phonenumber
        self.fcmToken = fcmToken
        self.coordinates = coordinates
        self.platform = platform
    }
}

