//
//  UberLocation.swift
//  GizeTransport
//
//  Created by User on 6/21/23.
//

import CoreLocation

struct UberLocation : Identifiable , Equatable {
    let id = NSUUID().uuidString
    let title: String
    let coordinate: CLLocationCoordinate2D
    static func ==(lhs: UberLocation, rhs: UberLocation) -> Bool {
        return lhs.id == rhs.id && lhs.title == rhs.title
    }
}
