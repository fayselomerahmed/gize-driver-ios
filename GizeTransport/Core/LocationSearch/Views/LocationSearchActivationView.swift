//
//  LocationSearchActivationView.swift
//  UberSwiftUitutorial
//
//  Created by User on 12/6/22.
//

import SwiftUI

struct LocationSearchActivationView: View {
    var body: some View {
        HStack {
            
            Circle()
                .fill(Color.black)
                .frame(width: 8 , height:  8)
                .padding(.horizontal)
            Text("Where to")
                .foregroundColor(Color(.systemGray))
            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width - 64 ,height: 70)
        .background(
            Rectangle()
                .fill(Color.white)
                .opacity(0.8)
                .shadow(color: .black, radius: 20))
        .opacity(0.8)
    }
}

struct LocationSearchActivationView_Previews: PreviewProvider {
    static var previews: some View {
        LocationSearchActivationView()
    }
}
