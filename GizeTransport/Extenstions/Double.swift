//
//  Double.swift
//  UberSwiftUitutorial
//
//  Created by User on 12/22/22.
//

import Foundation
extension Double {
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }
    func toCurrency() -> String {
        return currencyFormatter.string(for: self) ?? ""
    }
    private var distanceFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        // Set maximumFractionDigits to 1 if you want a single decimal place, or set it to 0 if you don't want any decimals.
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1  // Ensuring there's at least one decimal digit if the number has a fractional part
        return formatter
    }

    // Assuming this function is an extension of a numeric type, like Double
    func distanceInKilometersString() -> String {
        return distanceFormatter.string(for: self / 1000) ?? ""  // Convert meters to kilometers
    }

}
