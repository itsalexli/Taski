//
//  ContentView.swift
//  DeltaHacks2026
//
//  Created by Alexander Li on 2026-01-10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack{
            Color.black
                .ignoresSafeArea()
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
            }
            
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
