import SwiftUI

struct MyTasksView: View {
    @State private var myTasks: [TaskItem] = []
    
    var body: some View {
        ZStack {
            // Background is handled by ContentView, but we add a clear ZStack to hold structure
            VStack {
                // Header
                HStack {
                    Spacer()
                    Text("My Tasks") // Updated Title
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 15) {
                        if myTasks.isEmpty {
                            Text("No tasks yet.")
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 50)
                        } else {
                            ForEach(myTasks) { task in
                                // Reusing TaskRow from TaskScreen.swift
                                // Note: We do NOT add .onTapGesture here, making it non-clickable
                                TaskRow(task: task)
                            }
                        }
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear(perform: loadMyTasks)
        .padding()
    }
    
    func loadMyTasks() {
        if let data = UserDefaults.standard.data(forKey: "myTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            myTasks = decoded
        } else {
            // Dummy data for visualization since "myTasks" is currently empty
            myTasks = [
                TaskItem(title: "Completed Project A", price: "$200.00", biddingDate: Date(), dueDate: Date().addingTimeInterval(-86400)),
                TaskItem(title: "Consulting Gig", price: "$500.00", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400 * 3))
            ]
            // Save this dummy data so it persists
            if let encoded = try? JSONEncoder().encode(myTasks) {
                UserDefaults.standard.set(encoded, forKey: "myTasks")
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black // Preview background
        MyTasksView()
    }
}
