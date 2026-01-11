import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0 // 0: Home, 1: Tasks, 2: Add, 3: Data
    @State private var tasks: [TaskItem] = []
    @State private var userBalance: Double = 1250.00 // Added state
    
    // Solana Service for blockchain interaction
    @StateObject private var solanaService = SolanaService()
    @State private var showDepositAlert = false
    @State private var depositAmount: String = "0.01"

    var body: some View {
        ZStack {
            Image("appbackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ZStack {
                    if selectedTab == 0 {
                        homeView
                    } else if selectedTab == 1 {
                        // TAB 1: My Tasks (Read-only)
                        MyTasksView(solanaService: solanaService)
                    } else if selectedTab == 2 {
                        // TAB 2: Add / Available Tasks (Marketplace)
                        TaskScreen(showTaskScreen: .constant(true), solanaService: solanaService)
                    } else {
                        DataScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Navigation Bar
                HStack {
                    Spacer()
                    navButton(icon: "house.fill", label: "Home", index: 0)
                    Spacer()
                    navButton(icon: "checklist", label: "My Tasks", index: 1)
                    Spacer()
                    navButton(icon: "plus.circle.fill", label: "Add", index: 2)
                    Spacer()
                    navButton(icon: "chart.bar.fill", label: "Data", index: 3)
                    Spacer()
                }
                .padding(.top, 15)
                .padding(.bottom, 35)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 0.5).foregroundColor(.white.opacity(0.2)), alignment: .top)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            loadPreviewTasks()
            loadUserBalance()
        }
        .onChange(of: selectedTab) { newValue in
            if newValue == 0 {
                loadPreviewTasks() // Refresh data when switching back to Home
                loadUserBalance()
            }
        }
        .alert(isPresented: $showDepositAlert) {
            Alert(
                title: Text("Solana Escrow"),
                message: Text(solanaService.statusMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    var homeView: some View {
        VStack(spacing: 25) {
            // Header Title - centered
            Text("Taski")
                .foregroundColor(.white)
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .padding(.top, 60)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // MARK: - Balance Cards
            HStack(spacing: 15) {
                // Wallet Balance Card
                VStack(spacing: 8) {
                    Text("💳 Wallet")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(String(format: "%.6f", solanaService.balance)) SOL")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                // Vault Balance Card
                VStack(spacing: 8) {
                    Text("🔐 Vault")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(String(format: "%.6f", solanaService.vaultBalance)) SOL")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
            .padding(.horizontal, 35)
            
            // MARK: - Deposit Section
            VStack(spacing: 16) {
                // Amount Input
                HStack {
                    Text("Amount:")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("0.01", text: $depositAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 100)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    
                    Text("SOL")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Deposit Button
                Button(action: {
                    if let amount = Double(depositAmount), amount > 0 {
                        solanaService.depositSOL(amount: amount, teamId: 1)
                        showDepositAlert = true
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                        Text(solanaService.isProcessing ? "Processing..." : "Deposit to Vault")
                            .font(.system(.headline, design: .rounded))
                            .bold()
                    }
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [.green, Color(red: 0.0, green: 0.8, blue: 0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(20)
                }
                .disabled(solanaService.isProcessing)
                .padding(.horizontal, 35)
                
                Text(solanaService.statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.leading, 4)
            .padding(.trailing, 4)
            
            // Preview Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Quick Preview")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 35)
                
                if !tasks.isEmpty {
                    // Edge-to-edge marquee
                    InfiniteMarqueeView(tasks: tasks)
                        .frame(height: 140)
                } else {
                    Text("No tasks available")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 35)
                        .padding(.bottom, 20)
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    func navButton(icon: String, label: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: selectedTab == index ? .bold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
        }
        .foregroundColor(selectedTab == index ? .white : .white.opacity(0.4))
    }
    
    func loadPreviewTasks() {
        if let data = UserDefaults.standard.data(forKey: "savedTasks"),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            tasks = decoded
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

// MARK: - Consistent Marquee Components

struct InfiniteMarqueeView: View {
    let tasks: [TaskItem]
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { _ in
            let cardWidth: CGFloat = 170
            let spacing: CGFloat = 18
            let singleSetWidth = Double(tasks.count) * (cardWidth + spacing)
            
            HStack(spacing: spacing) {
                ForEach(0..<10, id: \.self) { _ in
                    ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                        TaskPreviewCard(task: task)
                            .frame(width: cardWidth)
                    }
                }
            }
            .offset(x: offset)
            .onAppear {
                // Ensure a smooth continuous loop
                withAnimation(.linear(duration: Double(tasks.count) * 3.0).repeatForever(autoreverses: false)) {
                    offset = -singleSetWidth
                }
            }
        }
    }
}

struct TaskPreviewCard: View {
    let task: TaskItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2) // Changed from 1 to 2
                .fixedSize(horizontal: false, vertical: true) // Prevent truncation
            
            Text(task.price)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.green)
            
            Spacer()
        }
        .padding(16)
        .frame(height: 120) // Enforce consistent height
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .compositingGroup()
    }
}

#Preview{
    ContentView()
}

