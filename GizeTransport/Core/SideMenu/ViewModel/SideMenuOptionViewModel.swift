//
//  SideMenuOptionViewModel.swift
//  GizeTransport
//
//  Created by User on 4/2/23.
//

import Foundation

enum SideMenuOptionViewModel: Int , CaseIterable , Identifiable {
    case trips
    case notification
    case wallet
    case bonus
    case preorder

    
    var title: String {
        switch self {
        case .trips: return "Earnings"
        case .notification: return "Notifications"
        case .wallet: return "Wallet"
        case .bonus: return "Bonus"
        case .preorder: return "Pre-orders"
        }
    }

    var subtitle: String {
        switch self {
        case .trips: return "Trips, payouts, and performance"
        case .notification: return "Dispatch alerts and reminders"
        case .wallet: return "Balance, top-ups, and payments"
        case .bonus: return "Incentives and driver rewards"
        case .preorder: return "Scheduled airport assignments"
        }
    }

    var imageName: String {
        switch self {
        case .trips: return "banknote.fill"
        case .notification: return "bell"
        case .wallet: return "creditcard"
       
        case .bonus: return "bubble.left"
        case .preorder: return "calendar"
        }
    }
    var id: Int {
        return self.rawValue
    }
}
