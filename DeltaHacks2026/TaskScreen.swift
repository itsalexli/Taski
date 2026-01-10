//
//  TaskScreen.swift
//  DeltaHacks2026
//
//  Created by Alexander Li on 2026-01-10.
//

import SwiftUI

// Data Model
struct TaskItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var price: String
    var biddingDate: Date
    var dueDate: Date
}

struct TaskScreen: View {
    @Binding var showTaskScreen: Bool
    
    // Data State
    @State private var tasks: [TaskItem] = []
    @State private var userBalance: Double = 1250.00 // Example User Balance
    
    // Bidding Popup State
    @State private var selectedTask: TaskItem? = nil
    @State private var bidInput: String = ""
    @State private var showBidError: Bool = false
    
    var body: some View {
        ZStack {
            // MARK: - Main Content
            VStack {
                // Header
                HStack {
                    Button(action: {
                        showTaskScreen = false
                    }) {
                        Image(systemName: "house.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Available Tasks")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Balance Display in Header
                    Text(String(format: "$%.0f", userBalance))
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(.green)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Task List
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(tasks) { task in
                            TaskRow(task: task)
                                .onTapGesture {
                                    // Open the bidding popup for this task
                                    openBidPopup(for: task)
                                }
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .blur(radius: selectedTask != nil ? 5 : 0) // Blur background when popup is open
            .disabled(selectedTask != nil) // Disable interaction with background
            
            // MARK: - Bidding Popup
            if let task = selectedTask {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePopup()
                    }
                
                VStack(spacing: 20) {
                    Text("Place Your Bid")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                    
                    Divider().background(Color.white.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Task: \(task.title)")
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Current Buy Price: \(task.price)")
                            .foregroundColor(.green)
                            .bold()
                        
                        Text("Your Balance: $\(String(format: "%.2f", userBalance))")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Input Field
                    TextField("Enter bid amount", text: $bidInput)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(showBidError ? Color.red : Color.clear, lineWidth: 1)
                        )
                    
                    if showBidError {
                        Text("Bid must be lower than current price.")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 15) {
                        // Close Button
                        Button(action: closePopup) {
                            Text("Close")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                        
                        // Bid Button
                        Button(action: placeBid) {
                            Text("Bid")
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(25)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 30)
                .transition(.scale)
            }
        }
        .onAppear(perform: loadTasks)
    }
    
    // MARK: - Logic Functions
    
    func openBidPopup(for task: TaskItem) {
        selectedTask = task
        bidInput = ""
        showBidError = false
    }
    
    func closePopup() {
        withAnimation {
            selectedTask = nil
        }
    }
    
    func placeBid() {
        guard let task = selectedTask,
              let bidValue = Double(bidInput),
              let currentPrice = Double(task.price.replacingOccurrences(of: "$", with: "")) else {
            return
        }
        
        // Logic: Bid must be LESS than current buy amount
        if bidValue < currentPrice {
            updateTaskPrice(taskID: task.id, newPrice: bidValue)
            closePopup()
        } else {
            showBidError = true
        }
    }
    
    func updateTaskPrice(taskID: UUID, newPrice: Double) {
        // 1. Update local list
        if let index = tasks.firstIndex(where: { $0.id == taskID }) {
            tasks[index].price = "$" + String(format: "%.0f", newPrice)
        }
        
        // 2. Update UserDefaults
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "savedTasks")
        }
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "savedTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        }
        
        if tasks.isEmpty {
            tasks = [
                TaskItem(title: "Fix broken window", price: "$120", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400 * 2)),
                TaskItem(title: "Mow the lawn", price: "$45", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400)),
                TaskItem(title: "Assemble IKEA Desk", price: "$60", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400 * 5))
            ]
        }
    }
}

// MARK: - Row View
struct TaskRow: View {
    let task: TaskItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Bid by")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(task.biddingDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Due")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(task.dueDate, style: .date)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
            
            Spacer()
            
            Text(task.price)
                .font(.headline)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
        // Add shape for better tap area
        .contentShape(Rectangle())
    }
}

#Preview {
    ZStack {
        Image("appbackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
        TaskScreen(showTaskScreen: .constant(true))
    }
}
