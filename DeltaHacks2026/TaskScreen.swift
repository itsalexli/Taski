//
//  TaskScreen.swift
//  DeltaHacks2026
//
//  Created by Alexander Li on 2026-01-10.
//

import SwiftUI

struct TaskScreen: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Image("appbackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16))
                            .padding(.leading,10)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)

    }
}

#Preview {
    TaskScreen()
}

