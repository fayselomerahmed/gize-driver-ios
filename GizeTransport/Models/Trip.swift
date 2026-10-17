//
//  Trip.swift
//  GizeTransport
//
//  Created by User on 6/6/23.
//




import Firebase
import FirebaseFirestoreSwift
import CoreLocation
import FirebaseDatabase

enum TripState: Int , Codable {
    case requested
    case rejected
    case accepted
    case arrived
    case noTrip
    case passengerCancelled
    case driverCancelled
    case starttrip
    case tripCompleted
    case preorder

    
}

enum TripType: Int , Codable {
    case now
    case preorder
    case manual
    
}
struct Trip: Codable, Identifiable  {
    @DocumentID var tripId: String?
    let passengerUid: String
    let driverUid: String
    let passengerName: String
    let driverName: String
    let passengerLocation: GeoPoint
    let driverLocation: GeoPoint
    var pickupLocationName: String
    var dropofflocationName: String
    let pickupLocationAddress: String
    let pickupLocation: GeoPoint
    let dropoffLocation: GeoPoint
    var tripCost: Double
    var distanceToPassenger: Double
    var travelTimeToPassenger: Int
    var preOrderDate: Date?
    var preOrderTime: Date?
    var state : TripState
    var tripType: TripType
    var rideType: RideType?
    var tripDate: Date?
    var timestamp: Timestamp?
    var distanceTraveled: Double?
    var platform: String? = "IOS"
    var fcmToken:String? = ""
//    var totalEarning = 0.0
    var dropoffLocationCoordinates: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: dropoffLocation.latitude, longitude: dropoffLocation.longitude)
    }
    
    var pickupLocationCoordiantes: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: pickupLocation.latitude, longitude: pickupLocation.longitude)
    }
    
    var dropoffUberLocation: UberLocation {
        return UberLocation(title: dropofflocationName, coordinate: dropoffLocationCoordinates)
    }
    
    var passengerFirstNameUppercased: String {
        let components = passengerName.components(separatedBy: " ")
        guard let firstName = components.first else { return passengerName.uppercased() }
        
        return firstName.uppercased()
    }
    // Use a computed property to get the ID, avoiding setting it manually
    var id: String {
        return tripId ?? ""
    }
}
extension Trip {
    func toDictionary() -> [String: Any] {
        // Convert all properties of Trip to a key-value pair dictionary
        return [
            "passengerUid": passengerUid,
            "driverUid": driverUid,
            // Add other properties similarly
        ]
    }
}
extension Date {
    func localFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        return self.formatted(date: date, time: time)
    }
}




