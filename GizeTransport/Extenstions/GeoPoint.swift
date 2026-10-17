//
//  GeoPoint.swift
//  GizeTransport
//
//  Created by User on 6/24/23.
//

import Firebase
import CoreLocation

extension GeoPoint {
    func toCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    }
