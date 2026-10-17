//
//  Wallet.swift
//  GizeDriver
//
//  Created by User on 10/7/23.
//
import SwiftUI
import Firebase

// 1. Define Constants for easy maintenance
struct Constants {
    static let deductionPercentage: Double = 0.12 // 12%
}

struct Wallet: View {
    // State variables
    @State private var walletBalance: Double = 0.0
    @State private var tripCompleted: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    @EnvironmentObject var viewModel: HomeViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            HStack {
                Spacer()
                Text("Wallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading, -40)
                Spacer()
            }
            
            Spacer().frame(height: 30)
            
            // Wallet Balance Card
            VStack(alignment: .leading, spacing: 10) {
                Text("Gize Transport")
                    .foregroundColor(.gray)
                
                Text(String(format: "%.2f ETB", walletBalance))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                Button(action: {
                    topUpWallet(amount: 50.0) // Example top-up amount
                }) {
                    HStack {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                        Text("Top up")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.black)
                .cornerRadius(10)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(Color.black)
            .cornerRadius(20)
            .padding(.horizontal)
            
            // Navigation Links List
            List {
                NavigationLink(destination: Text("Payment methods")) {
                    HStack {
                        Image(systemName: "creditcard")
                        Text("Payment methods")
                    }
                }
                NavigationLink(destination: Text("Transactions")) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Transactions")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .padding(.top, -20)
        }
        .padding()
        .onAppear {
            observeWalletBalance()
            // Removed fetchInitialWalletBalance as it's redundant with observeWalletBalance
        }
//        .onReceive(viewModel.$trip) { trip in
//            guard let trip = trip, trip.state == .tripCompleted else { return }
//            tripCompleted = true
//            viewModel.saveCompletedTrip(trip)
//            
//            // Calculate 12% deduction from the trip's total earning
//            let deductionAmount = trip.totalEarning * Constants.deductionPercentage
//            deductFromWallet(amount: deductionAmount)
//        }
        // Alert for error messages
        .alert(isPresented: Binding<Bool>(
            get: { self.errorMessage != nil },
            set: { if !$0 { self.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Transaction Failed"),
                message: Text(errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        // Alert for success messages
        .alert(isPresented: Binding<Bool>(
            get: { self.successMessage != nil },
            set: { if !$0 { self.successMessage = nil } }
        )) {
            Alert(
                title: Text("Success"),
                message: Text(successMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // 2. Observe wallet balance from Realtime Database
    private func observeWalletBalance() {
        guard let uid = viewModel.currentUser?.uid else {
            print("No user ID found.")
            return
        }
        
        let ref = Database.database().reference()
        let walletRef = ref.child("Wallet").child(uid).child("amount")
        
        walletRef.observe(.value) { snapshot in
            if let value = snapshot.value as? Double {
                walletBalance = value
            } else {
                print("Wallet balance not found.")
            }
        }
    }
    
    // 2. Deduct 12% from the wallet balance safely
    private func deductFromWallet(amount: Double) {
        guard let uid = viewModel.currentUser?.uid else {
            print("No user ID found.")
            self.errorMessage = "User not authenticated."
            return
        }
        
        let ref = Database.database().reference()
        let walletRef = ref.child("Wallet").child(uid).child("amount")
        
        // Perform transaction to ensure atomicity
        walletRef.runTransactionBlock { currentData in
            var currentBalance = currentData.value as? Double ?? 0.0
            print("Current Wallet Balance: \(currentBalance) ETB")
            
            // Check if sufficient balance exists
            if currentBalance >= amount {
                currentBalance -= amount
                currentData.value = currentBalance
                print("Deducted \(amount) ETB. New Balance: \(currentBalance) ETB")
                return TransactionResult.success(withValue: currentData)
            } else {
                // Insufficient funds; abort transaction
                print("Insufficient wallet balance. Deduction of \(amount) ETB not performed.")
                return TransactionResult.abort()
            }
        } andCompletionBlock: { error, committed, snapshot in
            if let error = error {
                print("Transaction failed: \(error.localizedDescription)")
                self.errorMessage = "Failed to deduct from wallet: \(error.localizedDescription)"
            } else if committed {
                if let newBalance = snapshot?.value as? Double {
                    DispatchQueue.main.async {
                        self.walletBalance = newBalance
                        self.successMessage = "Successfully deducted \(String(format: "%.2f", amount)) ETB from your wallet."
                    }
                    print("Wallet balance successfully updated to \(newBalance) ETB.")
                    
                    // Update Firestore with the new balance
                    updateWalletBalanceInFirestore(newBalance: newBalance)
                }
            } else {
                // Transaction aborted due to insufficient funds
                DispatchQueue.main.async {
                    self.errorMessage = "Insufficient funds in wallet for deduction."
                }
                print("Transaction aborted: Insufficient funds.")
            }
        }
    }
    
    // 3. Update wallet balance in Firestore to maintain consistency
    private func updateWalletBalanceInFirestore(newBalance: Double) {
        guard let uid = viewModel.currentUser?.uid else {
            print("No user ID found.")
            return
        }
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)
        
        userRef.setData(["wallet": newBalance], merge: true) { error in
            if let error = error {
                print("Failed to update wallet balance in Firestore: \(error.localizedDescription)")
                // Optionally, set an error message or handle the error as needed
            } else {
                print("Wallet balance updated successfully in Firestore.")
                // Optionally, perform additional actions upon successful update
            }
        }
    }
    
    // Top-up wallet function remains unchanged
    private func topUpWallet(amount: Double) {
        guard let uid = viewModel.currentUser?.uid else {
            print("No user ID found.")
            self.errorMessage = "User not authenticated."
            return
        }
        
        let ref = Database.database().reference()
        let walletRef = ref.child("Wallet").child(uid).child("amount")
        
        walletRef.runTransactionBlock { currentData in
            var value = currentData.value as? Double ?? 0.0
            value += amount
            currentData.value = value
            return TransactionResult.success(withValue: currentData)
        } andCompletionBlock: { error, committed, snapshot in
            if let error = error {
                print("Failed to top up wallet: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to top up wallet: \(error.localizedDescription)"
                }
            } else if committed {
                if let value = snapshot?.value as? Double {
                    DispatchQueue.main.async {
                        self.walletBalance = value
                        self.successMessage = "Successfully topped up \(String(format: "%.2f", amount)) ETB."
                    }
                }
                print("Wallet topped up successfully.")
            }
        }
    }
}

struct Wallet_Previews: PreviewProvider {
    static var previews: some View {
        Wallet()
            .environmentObject(HomeViewModel())
    }
}



