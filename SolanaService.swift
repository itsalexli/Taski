import Foundation
import Combine
import Solana

class SolanaService: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = "Ready to connect"
    @Published var balance: Double = 0.0
    
    // MARK: - Configuration
    // Update this IP to your Mac's LAN IP
    private let endpoint = "http://172.18.78.52:8899"
    private let programId = "TrSvGRr4F3aVXvyGMKQWaWYwFHawWcDaiL5WqUL6DVU"
    
    // Solana SDK
    private var solana: Solana?
    private var account: Account?
    
    init() {
        setupSolana()
    }
    
    func setupSolana() {
        let router = NetworkingRouter(endpoint: RPCEndpoint.custom(URL(string: endpoint)!))
        solana = Solana(router: router)
        
        // specific mnemonic for demo consistency or generate new
        // For this demo, we'll try to restore a hardcoded one or generate new
        // In a real app, use Keychain
        let mnemonic = "route clerk illness curve couple divorce hello verify visual senior moral cover"
        
        Task {
            do {
                account = try await Account(phrase: mnemonic.components(separatedBy: " "), network: .mainnetBeta)
                print("Wallet: \(account?.publicKey.base58EncodedString ?? "Unknown")")
                await updateBalance()
            } catch {
                print("Error creating account: \(error)")
                DispatchQueue.main.async { self.statusMessage = "Wallet Error" }
            }
        }
    }
    
    @MainActor
    func updateBalance() async {
        guard let solana = solana, let account = account else { return }
        do {
            let bal = try await solana.api.getBalance(account: account.publicKey.base58EncodedString)
            self.balance = Double(bal) / 1_000_000_000.0
            self.statusMessage = "Connected: \(String(format: "%.2f", self.balance)) SOL"
        } catch {
            self.statusMessage = "Balance Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Actions
    
    func depositSOL(amount: Double, teamId: UInt64) {
        Task {
            await performDeposit(amount: amount, teamId: teamId)
        }
    }
    
    func placeBid(lamports: UInt64, taskId: UInt64, teamId: UInt64) {
        Task {
            await performBid(lamports: lamports, taskId: taskId, teamId: teamId)
        }
    }
    
    // MARK: - Internal Logic
    
    @MainActor
    private func performDeposit(amount: Double, teamId: UInt64) async {
        guard let solana = solana, let account = account else { return }
        isProcessing = true
        statusMessage = "Depositing..."
        
        do {
            let lamports = UInt64(amount * 1_000_000_000)
            let programKey = PublicKey(string: programId)!
            
            // Derive PDAs
            // team = ["team", authority, team_id]
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let teamPDA = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, account.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            ).0
            
            // vault = ["vault", team_key]
            let vaultPDA = try PublicKey.findProgramAddress(
                seeds: ["vault".data(using: .utf8)!, teamPDA.data],
                programId: programKey
            ).0
            
            // Instruction Data
            // discriminator: deposit = [242, 35, 198, 137, 82, 225, 242, 182]
            var data = [UInt8]([242, 35, 198, 137, 82, 225, 242, 182])
            data.append(contentsOf: withUnsafeBytes(of: lamports.littleEndian) { Array($0) })
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: vaultPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: account.publicKey, isSigner: true, isWritable: true), // depositor
                    AccountMeta(publicKey: account.publicKey, isSigner: true, isWritable: false), // authority
                    AccountMeta(publicKey: PublicKey.systemProgramId, isSigner: false, isWritable: false)
                ],
                programId: programKey,
                data: data
            )
            
            let transactionId = try await solana.action.serializeAndSendWithFee(
                instructions: [instruction],
                signers: [account]
            )
            
            statusMessage = "Success! Tx: \(transactionId.prefix(8))..."
            await updateBalance()
            
        } catch {
            statusMessage = "Deposit Failed: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    @MainActor
    private func performBid(lamports: UInt64, taskId: UInt64, teamId: UInt64) async {
        guard let solana = solana, let account = account else { return }
        isProcessing = true
        statusMessage = "Placing Bid..."
        
        do {
             let programKey = PublicKey(string: programId)!
            
            // Re-derive the team to find the task (assuming user is team authority for simplicity of demo,
            // OR we need to know who the team authority is. 
            // FAIL CASE: If current user didn't create the team, we can't find the team seeds just by 'account.publicKey'.
            // For the demo to work across phones, we might need a hardcoded Team Authority Key or pass it in.
            // Simplification: We will assume we are bidding on a task created by THIS user for now 
            // OR we assume we know the team address. 
            
            // Let's hardcode a "Global Team Authority" for the demo purpose if we want cross-phone to work easily
            // or just rely on passing it. 
            // For now, let's assume the Team Authority IS the current user for the "Create/Deposit" flow,
            // but for "Bid", we need to know the Team key. 
            // I'll skip re-derivation if I can't know the authority.
            
            // FIXME: In a real app, TaskItem needs to store the `team` pubkey string.
            // For this quick bridge: I will use the current user as team authority for testing LOCALLY (1 phone).
            // To test 2 phones, phone A creates, phone B bids. Phone B needs Phone A's pubkey.
            
            // HACK: Use a fixed hardcoded 'Demo Team Authority' Mnemonic?
            // Actually, let's just use the current account as bidder.
            // We need to know the TASK PDA address.
            // task = ["task", team_key, task_id]
            
            // Assuming we stored `teamAddress` string in TaskItem? 
            // If not, we can't easily find the PDA.
            // Let's print out the logic error in the UI if needed, but for now I'll implement as if 
            // we know the team address. 
            
            // Placeholder: Assume self is team authority for testing
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
             let teamPDA = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, account.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            ).0
            
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let taskPDA = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            ).0
            
            
            // Discriminator: place_bid = [238, 77, 148, 91, 200, 151, 92, 146]
            var data = [UInt8]([238, 77, 148, 91, 200, 151, 92, 146])
            data.append(contentsOf: withUnsafeBytes(of: lamports.littleEndian) { Array($0) })
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: account.publicKey, isSigner: true, isWritable: false) // bidder
                ],
                programId: programKey,
                data: data
            )
            
            let transactionId = try await solana.action.serializeAndSendWithFee(
                instructions: [instruction],
                signers: [account]
            )
            
            statusMessage = "Bid Placed! Tx: \(transactionId.prefix(8))..."
            
        } catch {
             statusMessage = "Bid Failed: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}
