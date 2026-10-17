//
//  TripState.swift
//  GizeDriver
//
//  Created by User on 10/7/23.
//

import Foundation

enum TripState: Int, Codable {
    case driversUnavailable
    case rejectedByDriver
    case rejectedByAllDrivers
    case requested // value has to equal 3 to correspond to mapView tripRequested state
    case accepted
    case driverArrived
    case inProgress
    case arrivedAtDestination
    case complete
    case cancelled
}
