import SwiftUI

struct DataScreen: View {
    // Dummy data for party members
    let partyMembers = [
        PartyMember(name: "Jeff", tasksCompleted: 12, moneyEarned: 1450.75),
        PartyMember(name: "Liyu", tasksCompleted: 8, moneyEarned: 980.50),
        PartyMember(name: "Timothy", tasksCompleted: 15, moneyEarned: 1890.25)
    ]
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Spacer()
                Text("Party Stats")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 25) {
                    // Party Members Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Your Party")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        ForEach(partyMembers) { member in
                            PartyMemberCard(member: member)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Statistics Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Overall Statistics")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        // Stats Grid
                        VStack(spacing: 15) {
                            // Row 1
                            HStack(spacing: 15) {
                                StatCard(title: "Tasks Completed", value: "35", icon: "checkmark.circle.fill", color: .green)
                                StatCard(title: "Amount Earned", value: "$4,321.50", icon: "dollarsign.circle.fill", color: .green)
                            }
                            
                            // Row 2
                            HStack(spacing: 15) {
                                StatCard(title: "Active Bids", value: "8", icon: "hand.raised.fill", color: .green)
                                StatCard(title: "Success Rate", value: "94%", icon: "chart.line.uptrend.xyaxis", color: .green)
                            }
                            
                            // Row 3
                            HStack(spacing: 15) {
                                StatCard(title: "Avg Task Value", value: "$123.47", icon: "chart.bar.fill", color: .green)
                                StatCard(title: "Total Hours", value: "127", icon: "clock.fill", color: .green)
                            }
                            
                            // Row 4
                            HStack(spacing: 15) {
                                StatCard(title: "Win Streak", value: "12", icon: "flame.fill", color: .green)
                                StatCard(title: "Response Time", value: "2.3h", icon: "timer", color: .green)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            Spacer()
        }
        .padding()
    }
}

struct PartyMember: Identifiable {
    let id = UUID()
    let name: String
    let tasksCompleted: Int
    let moneyEarned: Double
}

struct PartyMemberCard: View {
    let member: PartyMember
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Picture
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.6), Color.mint.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                // Placeholder for profile picture - can be replaced with actual image
                Text(String(member.name.prefix(1)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
            )
            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Member Info
            VStack(alignment: .leading, spacing: 8) {
                // Name
                Text(member.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Stats Row
                HStack(spacing: 20) {
                    // Tasks Completed
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tasks")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text("\(member.tasksCompleted)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Money Earned
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Earned")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                            Text(String(format: "$%.2f", member.moneyEarned))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    DataScreen()
}
