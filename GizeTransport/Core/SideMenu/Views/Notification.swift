//
//  Notification.swift
//  GizeDriver
//
//  Created by User on 10/23/23.
//
import SwiftUI

struct Notification: View {
    var notificationTitle: String
    var notificationBody: String

    var body: some View {
        NavigationView {
            List {
                NotificationCard(
                    icon: "bell.fill",
                    title: notificationTitle,
                    bodyCon: notificationBody,
                    backgroundColor: Color.teal.opacity(0.1)
                )
                
                NotificationCard(
                    icon: "star.fill",
                    title: "Bonus Points",
                    bodyCon: "You have used your bonus points for a car wash",
                    backgroundColor: Color.teal.opacity(0.1)
                )
            }
            .navigationTitle("Notifications")
            .listStyle(PlainListStyle())
        }
    }
}


struct Notification_Previews: PreviewProvider {
    static var previews: some View {
        Notification(
            notificationTitle: "New Ride Request",
            notificationBody: "You have a new ride request. Check it out!"
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}


import SwiftUI
struct NotificationCard: View {
    var icon: String
    var title: String
    var bodyCon: String
    var backgroundColor: Color
    
    var bodyContent: some View { // Changed to avoid redeclaration error
        HStack {
            Image(systemName: icon)
                .foregroundColor(.darkGreen)
                .font(.title2)
                .padding(.trailing, 10)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(bodyCon)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    var body: some View {
        bodyContent // Use bodyContent to avoid redeclaration error
    }
}






