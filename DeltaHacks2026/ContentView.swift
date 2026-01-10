//
//  ContentView.swift
//  DeltaHacks2026
//
//  Created by Alexander Li on 2026-01-10.
//

import SwiftUI

struct ContentView: View {
    // Controls which view is visible to remove slide animation
    @State private var showTaskScreen = false
    
    var body: some View {
        ZStack {
            // Persistent Background
            Image("appbackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            if showTaskScreen {
                // Pass the binding so TaskScreen can dismiss itself
                TaskScreen(showTaskScreen: $showTaskScreen)
                    .transition(.identity) // Ensures no animation occurs
            } else {
                // HOME SCREEN CONTENT
                VStack(spacing: 30) {
                    Text("Taski")
                        .foregroundColor(.white)
                        .bold()
                        .font(.title)
                        .offset(y: -300)
                    
                    Button(action: {
                        showTaskScreen = true
                    }) {
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
                .transition(.identity)
            }
        }
    }
}

#Preview {
    ContentView()
}
