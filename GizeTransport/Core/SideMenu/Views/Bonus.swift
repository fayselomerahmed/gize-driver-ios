//
//  Bonus.swift
//  GizeDriver
//
//  Created by User on 10/7/23.
//
import SwiftUI
import Firebase
import FirebaseFirestore

struct Bonus: View {
    @State private var distanceTraveled: Int = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @EnvironmentObject var viewModel: HomeViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
//                Button(action: {
//                    // Action for back button
//                }) {
//                    Image(systemName: "arrow.left")
//                        .font(.title)
//                        .foregroundColor(.white)
//                        .padding()
//                        .background(Color.green)
//                        .clipShape(Circle())
//                }
                
                Spacer()
                
                Text("Bonus")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer().frame(height: 20)
            
            // Mile Display Section
            Text("Your Mile: \(distanceTraveled) KM")
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal)
            
            // Bonus Cards
            ScrollView {
                VStack(spacing: 20) {
                    BonusCardView(title: "Car Wash", bonusDistance: "10,000 KM", dateRange: "01 Jan 2025 To 12 Jun 2026", distanceTraveled: $distanceTraveled, requiredMiles: 10000) {
                        redeemBonus(requiredMiles: 10000)
                    }
                    BonusCardView(title: "5 Litre Oil Change", bonusDistance: "200,000 KM", dateRange: "01 Jan 2025 To 12 Jun 2025", distanceTraveled: $distanceTraveled, requiredMiles: 2000) {
                        redeemBonus(requiredMiles: 2000)
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Notice"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            fetchDistanceTraveled()
        }
    }
    
    private func fetchDistanceTraveled() {
        guard let uid = viewModel.currentUser?.uid else {
            print("No user ID found.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        userRef.getDocument { document, error in
            if let document = document, document.exists {
                if let distance = document.data()?["distanceTraveled"] as? Int {
                    DispatchQueue.main.async {
                        self.distanceTraveled = distance
                    }
                } else {
                    print("Distance traveled not found.")
                }
            } else {
                print("Document does not exist")
            }
        }
    }
    
    private func redeemBonus(requiredMiles: Int) {
        if distanceTraveled >= requiredMiles {
            distanceTraveled -= requiredMiles
            updateDistanceTraveled()
            alertMessage = "Points redeemed successfully"
        } else {
            alertMessage = "Not enough miles"
        }
        showAlert = true
    }
    
    private func updateDistanceTraveled() {
        guard let uid = viewModel.currentUser?.uid else {
            print("No user ID found.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        userRef.updateData(["distanceTraveled": distanceTraveled]) { error in
            if let error = error {
                print("Error updating distance traveled: \(error)")
            } else {
                print("Distance traveled updated successfully")
            }
        }
    }
}

struct BonusCardView: View {
    var title: String
    var bonusDistance: String
    var dateRange: String
    @Binding var distanceTraveled: Int
    var requiredMiles: Int
    var redeemAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            Text("Bonus Distance = \(bonusDistance)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(dateRange)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button(action: {
                redeemAction()
            }) {
                Text("Achieve")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
}

struct Bonus_Previews: PreviewProvider {
    static var previews: some View {
        Bonus()
            .environmentObject(HomeViewModel())
    }
}
