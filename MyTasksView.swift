import SwiftUI

struct MyTasksView: View {

    // MARK: - Data State
    @State private var myTasks: [TaskItem] = []
    @State private var selectedTask: TaskItem? = nil
    @State private var userBalance: Double = 1250.00
    
    // Timer for countdown
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeNow = Date()
    // MARK: - State
    @State private var showCamera = false
    @State private var inputImage: UIImage?
    @State private var isVerifying = false
    @State private var showVerificationError = false
    @State private var verificationErrorMessage = ""
    
    // Gemini Verifier
    private let verifier = GeminiVerifier()
    
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
                    .onTapGesture { if !isVerifying { closePopup() } }
                
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
                        .disabled(isVerifying)
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
                        .disabled(isVerifying)
                        
                        // Verified Complete (Camera) Button
                        Button(action: {
                            showCamera = true
                        }) {
                            HStack {
                                if isVerifying {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "camera.fill")
                                    Text("Verify & Complete")
                                }
                            }
                            .font(.headline)
                            .bold()
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green) // Solid green background for prominence
                            .cornerRadius(10)
                        }
                        .disabled(isVerifying)
                    }
                }
                .padding(25)
                .background(RoundedRectangle(cornerRadius: 25).fill(.ultraThinMaterial))
                .padding(.horizontal, 30)
                .overlay(
                    // Loading Overlay Message
                    Group {
                        if isVerifying {
                            VStack(spacing: 10) {
                                Text("Analyzing with Gemini...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Please wait")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(15)
                            .offset(y: -150) // Move up so it's visible above popup
                        }
                    }
                )
            }
        }
        .onAppear(perform: {
            loadMyTasks()
            loadUserBalance()
        })
        .onReceive(timer) { input in timeNow = input }
        .padding(0)
        
        // MARK: - Camera Sheet
        .sheet(isPresented: $showCamera, onDismiss: processcapturedImage) {
            ImagePicker(image: $inputImage, isPresented: $showCamera)
        }
        // MARK: - Error Alert
        .alert("Verification Failed", isPresented: $showVerificationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(verificationErrorMessage)
        }
    }
    
    // MARK: - Logic
    
    func processcapturedImage() {
        guard let image = inputImage, let task = selectedTask else { return }
        
        isVerifying = true
        
        Task {
            do {
                let isVerified = try await verifier.verifyTask(title: task.title, image: image)
                
                await MainActor.run {
                    isVerifying = false
                    inputImage = nil // Reset
                    
                    if isVerified {
                        completeTask(task)
                    } else {
                        verificationErrorMessage = "Gemini AI analyzed your photo and determined it DOES NOT verify the task: \"\(task.title)\".\n\nPlease try again with a clearer photo or manually verify with an admin."
                        showVerificationError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    inputImage = nil
                    verificationErrorMessage = "Error connecting to AI verification: \(error.localizedDescription)"
                    showVerificationError = true
                }
            }
        }
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
        // Get task value
        let priceString = task.price.replacingOccurrences(of: "$", with: "")
        if let taskValue = Double(priceString) {
            // Add to user balance
            userBalance += taskValue
            UserDefaults.standard.set(userBalance, forKey: "userBalance")
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
        MyTasksView()
    }
}
