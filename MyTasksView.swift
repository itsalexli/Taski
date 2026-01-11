import SwiftUI

struct MyTasksView: View {
    @State private var myTasks: [TaskItem] = []
    @State private var selectedTask: TaskItem? = nil
    @State private var userBalance: Double = 1250.00
    @ObservedObject var solanaService: SolanaService
    
    // Timer for countdown
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeNow = Date()
    
    var body: some View {
        ZStack {
            // Background is handled by ContentView, but we add a clear ZStack to hold structure
            VStack(spacing: 0) {
                // Header (Matching TaskScreen style)
                HStack {
                    VStack(alignment: .leading) {
                        Text("My Tasks")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Active & Completed")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 25)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                ScrollView {
                    VStack(spacing: 20) { // Increased spacing to 20 to match TaskScreen
                        if myTasks.isEmpty {
                            Text("No tasks yet.")
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 50)
                        } else {
                            ForEach(myTasks) { task in
                                TaskRow(task: task, currentTime: timeNow)
                                    .onTapGesture { openTaskPopup(for: task) }
                            }
                        }
                    }
                    .padding(.horizontal, 25) // Match TaskScreen padding
                    .padding(.top, 10)
                }
            }
            .blur(radius: selectedTask != nil ? 10 : 0)
            .disabled(selectedTask != nil)
            // Task Action Popup
            if let task = selectedTask {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { closePopup() }
                
                VStack(spacing: 20) {
                    // Header with title and X button
                    HStack {
                        Text(task.title)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Exit X Button
                        Button(action: { closePopup() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(8)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.5))
                    
                    // Task Value
                    HStack {
                        Text("Task Value: \(task.price)")
                            .foregroundColor(.green)
                            .bold()
                        Spacer()
                    }
                    
                    // Action Buttons
                    HStack(spacing: 15) {
                        // Discard Button
                        Button(action: { discardTask(task) }) {
                            Text("Discard")
                                .font(.headline)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                        }
                        
                        // Completed Button
                        Button(action: { completeTask(task) }) {
                            Text("Completed")
                                .font(.headline)
                                .bold()
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.green, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(25)
                .background(RoundedRectangle(cornerRadius: 25).fill(.ultraThinMaterial))
                .padding(.horizontal, 30)
            }
        }
        .onAppear(perform: {
            loadMyTasks()
            loadUserBalance()
        })
        .onReceive(timer) { input in timeNow = input }
        .padding()
    }
    
    func loadMyTasks() {
        // Load from saved data, or create demo data if empty
        if let data = UserDefaults.standard.data(forKey: "myTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data),
           !decoded.isEmpty {
            myTasks = decoded
        } else {
            // Demo tasks - Task #3 exists on-chain with 0.001 SOL reward
            myTasks = [
                TaskItem(title: "Blockchain Demo Task", price: "0.001 SOL", biddingDate: Date(), dueDate: Date().addingTimeInterval(-86400), onChainTaskId: 3)
            ]
            saveMyTasks()
        }
    }
    
    func loadUserBalance() {
        userBalance = UserDefaults.standard.double(forKey: "userBalance")
        if userBalance == 0 {
            userBalance = 1250.00 // Default balance
            UserDefaults.standard.set(userBalance, forKey: "userBalance")
        }
    }
    
    func openTaskPopup(for task: TaskItem) {
        selectedTask = task
    }
    
    func closePopup() {
        withAnimation(.spring()) {
            selectedTask = nil
        }
    }
    
    func discardTask(_ task: TaskItem) {
        // Remove from myTasks
        if let index = myTasks.firstIndex(where: { $0.id == task.id }) {
            myTasks.remove(at: index)
            saveMyTasks()
        }
        
        // Add back to marketplace (savedTasks)
        var marketplaceTasks: [TaskItem] = []
        if let data = UserDefaults.standard.data(forKey: "savedTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            marketplaceTasks = decoded
        }
        marketplaceTasks.append(task)
        if let encoded = try? JSONEncoder().encode(marketplaceTasks) {
            UserDefaults.standard.set(encoded, forKey: "savedTasks")
        }
        
        closePopup()
    }
    
    func completeTask(_ task: TaskItem) {
        // Call blockchain payout using the task's on-chain ID
        if let onChainId = task.onChainTaskId {
            solanaService.completeAndPayout(taskId: onChainId, teamId: 1)
        }
        
        // Remove from myTasks
        if let index = myTasks.firstIndex(where: { $0.id == task.id }) {
            myTasks.remove(at: index)
            saveMyTasks()
        }
        
        closePopup()
    }
    
    func saveMyTasks() {
        if let encoded = try? JSONEncoder().encode(myTasks) {
            UserDefaults.standard.set(encoded, forKey: "myTasks")
        }
    }
}

#Preview {
    ZStack {
        Color.black // Preview background
        MyTasksView(solanaService: SolanaService())
    }
}
