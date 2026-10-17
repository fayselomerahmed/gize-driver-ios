//
//  RideType.swift
//  UberSwiftUitutorial
//
//  Created by User on 12/22/22.
//

import Foundation
enum RideType: Int, Codable {
    case Economy
    case Comfort
    case Luxury
    
    var baseFare: Double {
        switch self {
        case .Economy: return 5.0
        case .Comfort: return 10.0
        case .Luxury: return 20.0
        }
    }
    
    var costPerKm: Double {
        switch self {
        case .Economy: return 1.0
        case .Comfort: return 1.5
        case .Luxury: return 2.0
        }
    }
    func computePrice(for distanceInMeters: Double) -> Double {
        let distanceInKilometers = distanceInMeters / 1000
        let baseFare = 100.0  // Example base fare
        let perKilometerRate = 12.0  // Example rate per kilometer
        return baseFare + (perKilometerRate * distanceInKilometers)
    }
}
