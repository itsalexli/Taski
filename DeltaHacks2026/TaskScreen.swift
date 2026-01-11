import SwiftUI
import Combine

// MARK: - Data Model

struct TaskItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var price: String
    var biddingDate: Date
    var dueDate: Date
    var isUserLastBidder: Bool = false
    var onChainTaskId: UInt64? = nil  // Maps to blockchain task
    
    // Custom decoding to handle legacy data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        price = try container.decode(String.self, forKey: .price)
        biddingDate = try container.decode(Date.self, forKey: .biddingDate)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        isUserLastBidder = try container.decodeIfPresent(Bool.self, forKey: .isUserLastBidder) ?? false
        onChainTaskId = try container.decodeIfPresent(UInt64.self, forKey: .onChainTaskId)
    }
    
    // Memberwise init needed since we added custom init
    init(id: UUID = UUID(), title: String, price: String, biddingDate: Date, dueDate: Date, isUserLastBidder: Bool = false, onChainTaskId: UInt64? = nil) {
        self.id = id
        self.title = title
        self.price = price
        self.biddingDate = biddingDate
        self.dueDate = dueDate
        self.isUserLastBidder = isUserLastBidder
        self.onChainTaskId = onChainTaskId
    }
}

struct TaskScreen: View {
    @Binding var showTaskScreen: Bool
    
    // Inject Service
    @ObservedObject var solanaService: SolanaService
    
    @State private var tasks: [TaskItem] = []
    @State private var userBalance: Double = 1250.00
    @State private var selectedTask: TaskItem? = nil
    @State private var bidInput: String = ""
    @State private var showBidError: Bool = false
    
    // Sheet State
    @State private var showAddTaskSheet = false
    
    // Timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var timeNow = Date()
    
    var body: some View {
        ZStack {
            // Main Content
            VStack(spacing: 0) {
                // MARK: - Modern Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Marketplace")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Available Tasks")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Wallet Badge
                    HStack(spacing: 8) {
                        Image(systemName: "wallet.pass.fill")
                            .foregroundColor(.green)
                        Text(String(format: "$%.2f", userBalance))
                            .font(.system(.subheadline, design: .rounded))
                            .bold()
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }
                .padding(.horizontal, 25) // Increased padding
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                // MARK: - Task List
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(tasks) { task in
                            TaskRow(task: task, currentTime: timeNow)
                                .onTapGesture { openBidPopup(for: task) }
                        }
                        // Spacer for Floating Button
                        Color.clear.frame(height: 80)
                    }
                    .padding(.horizontal, 25) // Increased padding for list items
                    .padding(.top, 10)
                }
            }
            .blur(radius: selectedTask != nil ? 10 : 0)
            .disabled(selectedTask != nil)
            .padding()
            
            // MARK: - Floating Add Button
            if selectedTask == nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddTaskSheet = true }) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 30) // Adjusted for new padding
                        .padding(.bottom, 25)
                    }
                }
            }

            // MARK: - Bidding Popup
            if let task = selectedTask {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { closePopup() }
                
                VStack(spacing: 25) {
                    // Popup Header
                    VStack(spacing: 5) {
                        Text("Place Your Bid")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text(task.title)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Info Row
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Current Price")
                                .font(.caption).foregroundColor(.gray)
                            Text(task.price)
                                .font(.title3).bold().foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Your Balance")
                                .font(.caption).foregroundColor(.gray)
                            Text(String(format: "$%.2f", userBalance))
                                .font(.title3).bold().foregroundColor(.white)
                        }
                    }
                    
                    // Input Field
                    TextField("0.00", text: $bidInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 15).fill(Color.white.opacity(0.1)))
                        .foregroundColor(.white)
                        .onChange(of: bidInput) { newValue in
                            filterDecimalInput(newValue: newValue, binding: $bidInput)
                        }
                    
                    if showBidError {
                        Text("Bid must be lower than current price.")
                            .foregroundColor(.red)
                            .font(.caption)
                            .transition(.opacity)
                    }
                    
                    // Action Buttons
                    HStack(spacing: 15) {
                        Button(action: { closePopup() }) {
                            Text("Cancel")
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(15)
                        }
                        
                        Button(action: { placeBid() }) {
                            Text("Confirm Bid")
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(15)
                                .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 25) // Ensure popup has side padding
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear(perform: {
            loadTasks()
            loadUserBalance()
        })
        .onReceive(timer) { input in
            timeNow = input
            checkExpirations() // Check for expired tasks every second
        }
        .padding(0)
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskView(tasks: $tasks, solanaService: solanaService)
        }
    }
    
    // MARK: - Logic & Helpers
    func filterDecimalInput(newValue: String, binding: Binding<String>) {
        let filtered = newValue.filter { "0123456789.".contains($0) }
        if filtered.contains(".") {
            let parts = filtered.components(separatedBy: ".")
            if parts.count > 2 {
                binding.wrappedValue = String(filtered.prefix(filtered.count - 1))
            } else if parts[1].count > 2 {
                binding.wrappedValue = parts[0] + "." + parts[1].prefix(2)
            } else { binding.wrappedValue = filtered }
        } else { binding.wrappedValue = filtered }
    }
    
    func openBidPopup(for task: TaskItem) {
        selectedTask = task
        bidInput = ""
        showBidError = false
    }
    
    func closePopup() { withAnimation(.spring()) { selectedTask = nil } }
    
    func placeBid() {
        guard let task = selectedTask, let bidValue = Double(bidInput),
              let currentPrice = Double(task.price.replacingOccurrences(of: "$", with: "")) else { return }
        
        if bidValue < currentPrice {
            // Update Price and set user as last bidder
            updateTask(taskID: task.id, newPrice: bidValue, isLastBidder: true)
            
            // Blockchain Call
            let lamports = UInt64(bidValue * 1_000_000_000)
            solanaService.placeBid(lamports: lamports, taskId: 101, teamId: 1) // Hardcoded IDs for demo
            
            closePopup()
        } else { withAnimation { showBidError = true } }
    }
    
    func updateTask(taskID: UUID, newPrice: Double, isLastBidder: Bool) {
        if let index = tasks.firstIndex(where: { $0.id == taskID }) {
            tasks[index].price = "$" + String(format: "%.2f", newPrice)
            tasks[index].isUserLastBidder = isLastBidder
        }
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "savedTasks")
        }
    }
    
    func checkExpirations() {
        // Filter expired tasks
        let now = Date()
        let expiredIndices = tasks.indices.filter { tasks[$0].dueDate < now }
        
        if expiredIndices.isEmpty { return }
        
        // Load MyTasks
        var myTasks: [TaskItem] = []
        if let data = UserDefaults.standard.data(forKey: "myTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            myTasks = decoded
        }
        
        var indicesToRemove: [Int] = []
        
        for index in expiredIndices {
            let task = tasks[index]
            if task.isUserLastBidder {
                // User won this task!
                // Add to My Tasks if not already there
                if !myTasks.contains(where: { $0.id == task.id }) {
                    myTasks.append(task)
                }
            }
            // Whether won or lost, it leaves the marketplace
            indicesToRemove.append(index)
        }
        
        // Remove from marketplace (reverse order)
        for index in indicesToRemove.sorted(by: >) {
            tasks.remove(at: index)
        }
        
        // Save Updates
        if !indicesToRemove.isEmpty {
            // Save Marketplace
            if let encoded = try? JSONEncoder().encode(tasks) {
                UserDefaults.standard.set(encoded, forKey: "savedTasks")
            }
            
            // Save MyTasks
            if let encoded = try? JSONEncoder().encode(myTasks) {
                UserDefaults.standard.set(encoded, forKey: "myTasks")
            }
        }
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "savedTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
        } else {
            // NOTE: Fallback defaults if decode fails or empty
            tasks = [
                TaskItem(title: "Fix broken window", price: "0.05 SOL", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400 * 2 + 3600)),
                TaskItem(title: "Mow the lawn", price: "0.02 SOL", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400 * 1 + 1800)),
                TaskItem(title: "Assemble IKEA Desk", price: "0.03 SOL", biddingDate: Date(), dueDate: Date().addingTimeInterval(86400 * 5 + 7200))
            ]
            // Save defaults immediately so ContentView can see them
            if let encoded = try? JSONEncoder().encode(tasks) {
                UserDefaults.standard.set(encoded, forKey: "savedTasks")
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
}

// MARK: - New Better Task Row
struct TaskRow: View {
    let task: TaskItem
    var currentTime: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Section: Title & Price
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        if currentTime > task.dueDate {
                            Text(task.isUserLastBidder ? "Won" : "Closed")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(task.isUserLastBidder ? .green.opacity(0.8) : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(task.isUserLastBidder ? Color.green.opacity(0.15) : Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        } else {
                            Text("Bid Open")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.green.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        if task.isUserLastBidder {
                            Text("Highest Bidder")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.yellow.opacity(0.5), lineWidth: 1))
                        }
                    }
                }
                
                Spacer()
                
                // Price Badge
                Text(task.price)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.5), radius: 5, x: 0, y: 2)
            }
            .padding(15)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Bottom Section: Countdown
            HStack {
                Label {
                    Text(getCountdownString(to: task.dueDate))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                } icon: {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text("Ends " + task.dueDate.formatted(.dateTime.day().month()))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(15)
            .background(Color.black.opacity(0.2))
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    func getCountdownString(to endDate: Date) -> String {
        let calendar = Calendar.current
        if currentTime >= endDate { return "00d : 00h : 00m : 00s" }
        let c = calendar.dateComponents([.day, .hour, .minute, .second], from: currentTime, to: endDate)
        return String(format: "%02dd : %02dh : %02dm : %02ds", c.day ?? 0, c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}

// MARK: - Add Task View
struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [TaskItem]
    @ObservedObject var solanaService: SolanaService
    
    @State private var title = ""
    @State private var price = ""
    @State private var dueDate = Date().addingTimeInterval(86400)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 25) {
                Text("New Task Offering")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Divider().background(Color.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 20) {
                    inputGroup(title: "Task Title", placeholder: "e.g. Clean Garage", text: $title)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price").font(.caption).foregroundColor(.gray)
                        TextField("0.00", text: $price)
                            .keyboardType(.decimalPad)
                            .onChange(of: price) { val in filterDecimalInput(val) }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                            .foregroundColor(.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Due Date").font(.caption).foregroundColor(.gray)
                        DatePicker("", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 15) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    Button(action: { saveTask() }) {
                        Text("Publish Task")
                            .bold()
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(title.isEmpty || price.isEmpty ? Color.green.opacity(0.3) : Color.green)
                            .cornerRadius(12)
                    }
                    .disabled(title.isEmpty || price.isEmpty)
                }
                .padding(.bottom, 20)
            }
            // MARK: ADDED PADDING HERE
            // This padding ensures the entire Add Task form has breathing room from the edges
            .padding(.horizontal, 25)
        }
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.visible)
    }
    
    func inputGroup(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.gray)
            TextField(placeholder, text: text)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
                .foregroundColor(.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))
        }
    }
    
    func filterDecimalInput(_ val: String) {
        let filtered = val.filter { "0123456789.".contains($0) }
        if filtered.contains(".") {
            let parts = filtered.components(separatedBy: ".")
            if parts.count > 2 { price = String(filtered.prefix(filtered.count - 1)) }
            else if parts[1].count > 2 { price = parts[0] + "." + parts[1].prefix(2) }
            else { price = filtered }
        } else { price = filtered }
    }
    
    func saveTask() {
        var finalPrice = price.trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalPrice.hasSuffix("SOL") { finalPrice = "\(finalPrice) SOL" }
        
        // Parse SOL amount for blockchain
        let solString = finalPrice.replacingOccurrences(of: " SOL", with: "")
        let solAmount = Double(solString) ?? 0.01 // Default to 0.01 if parse fails
        let lamports = UInt64(solAmount * 1_000_000_000)
        
        // Generate unique Task ID
        let taskId = UInt64(Date().timeIntervalSince1970)
        
        print("🚀 Creating Task #\(taskId) for \(lamports) lamports...")
        
        Task {
            // Create on blockchain (short 5s auction for demo)
            let success = await solanaService.createTask(taskId: taskId, rewardLamports: lamports, teamId: 1, auctionDurationSeconds: 5)
            
            await MainActor.run {
                if success {
                    let newTask = TaskItem(title: title, price: finalPrice, biddingDate: Date(), dueDate: dueDate, onChainTaskId: taskId)
                    tasks.append(newTask)
                    if let encoded = try? JSONEncoder().encode(tasks) { UserDefaults.standard.set(encoded, forKey: "savedTasks") }
                    
                    // Demo: Also add to "My Tasks" so we can complete it immediately
                    var myTasksList: [TaskItem] = []
                    if let data = UserDefaults.standard.data(forKey: "myTasks"),
                       let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
                        myTasksList = decoded
                    }
                    myTasksList.append(newTask)
                    if let encoded = try? JSONEncoder().encode(myTasksList) { UserDefaults.standard.set(encoded, forKey: "myTasks") }
                    
                    dismiss()
                } else {
                    // Start simple: just dismiss but log error (in real app, show alert)
                    print("Could not create task on chain")
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    TaskScreen(showTaskScreen: .constant(true), solanaService: SolanaService())
}
