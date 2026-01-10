//
//  ContentView.swift
//  DeltaHacks2026
//
//  Created by Alexander Li on 2026-01-10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ZStack{
                Image("appbackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Text("Taski")
                        .foregroundColor(.white)
                        .bold()
                        .font(.title)
                        .offset(y: -300)
                    
                    NavigationLink(destination: TaskScreen()) {
                        Text("Just Started")
                            .foregroundColor(.white)
                            .font(.headline)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .offset(y: -250)
                }
            }
        }
        .transaction { $0.disablesAnimations = true }
    }
}



#Preview {
    ContentView()
}
