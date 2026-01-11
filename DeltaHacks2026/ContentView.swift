import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0 // 0: Home, 1: Tasks, 2: Add, 3: Data
    @State private var tasks: [TaskItem] = []

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
                        MyTasksView()
                    } else if selectedTab == 2 {
                        // TAB 2: Add / Available Tasks (Marketplace)
                        TaskScreen(showTaskScreen: .constant(true))
                    } else {
                        Text("Data Analytics").foregroundColor(.white)
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
        .onAppear(perform: loadPreviewTasks)
        // Refresh data when switching back to Home to see newly added tasks
        .onChange(of: selectedTab) { newValue in
            if newValue == 0 {
                loadPreviewTasks()
            }
        }
    }
    
    var homeView: some View {
        VStack(spacing: 30) {
            Text("Taski").foregroundColor(.white).bold().font(.largeTitle).padding(.top, 100)
            Spacer()
            
            // Preview Section
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Preview")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 25)
                
                if !tasks.isEmpty {
                    InfiniteMarqueeView(tasks: tasks)
                        .frame(height: 100)
                        .clipped()
                } else {
                    Text("No tasks available")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 25)
                }
            }
            .padding(.bottom, 60)
        }
    }
    
    func navButton(icon: String, label: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22))
                Text(label).font(.system(size: 10))
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
}

// MARK: - Infinite Scrolling Components

struct InfiniteMarqueeView: View {
    let tasks: [TaskItem]
    @State private var offset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth: CGFloat = 160
            let spacing: CGFloat = 15
            // Total width of one "set" of data
            let singleSetWidth = Double(tasks.count) * (cardWidth + spacing)
            
            // We use HStack instead of ScrollView to lock layout
            HStack(spacing: 15) {
                // Duplicate the data enough times to fill the screen + buffer for looping
                ForEach(0..<10, id: \.self) { _ in
                    ForEach(Array(tasks.enumerated()), id: \.offset) { _, task in
                        TaskPreviewCard(task: task)
                    }
                }
            }
            .offset(x: offset)
            .onAppear {
                // Animate smoothly to the left
                withAnimation(.linear(duration: Double(tasks.count) * 2.5).repeatForever(autoreverses: false)) {
                    offset = -singleSetWidth
                }
            }
        }
    }
}

struct TaskPreviewCard: View {
    let task: TaskItem
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(task.title)
                .bold()
                .foregroundColor(.white)
                .lineLimit(1)
            Text(task.price)
                .foregroundColor(.green)
                .font(.subheadline)
        }
        .padding()
        .frame(width: 160)
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .compositingGroup()
    }
}

#Preview{
    ContentView()
}
