import SwiftUI

struct EmergencyButtonView: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: emergencyCall) {
            VStack {
                Image(systemName: "exclamationmark.triangle.fill") // Icon representing emergency (e.g., a warning sign)
                    .font(.largeTitle)
                Text("SOS")
                    .fontWeight(.bold)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding()
            .background(Color.red)
            .clipShape(Circle())
            .frame(width: 80, height: 80)
            .shadow(radius: 10)
        }
        .padding()
        .buttonStyle(PlainButtonStyle()) // Ensures no default styling interferes with your custom design
    }
    
    private func emergencyCall() {
        // Example action: print a message or perform a more complex operation
        print("Emergency button tapped")
        
        // To open a phone dialer (not executable in SwiftUI directly; requires integration with UIKit):
        if let url = URL(string: "tel://911"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

struct EmergencyButtonView_Previews: PreviewProvider {
    static var previews: some View {
        EmergencyButtonView(action: { print("Emergency Button Tapped") })
    }
}
