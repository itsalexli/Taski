import Foundation
import Combine
import SolanaSwift

class SolanaService: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = "Ready to connect"
    @Published var balance: Double = 0.0
    @Published var vaultBalance: Double = 0.0
    
    private let endpointURL = "https://api.devnet.solana.com"
    private let programId = "TrSvGRr4F3aVXvyGMKQWaWYwFHawWcDaiL5WqUL6DVU"
    private let vaultPDA = "5vBDkRZUZoGDTMNgzZMdHjtNSqFjox89zJLoeCxrF2Kh" // Team 1 vault
    
    private var keyPair: KeyPair?
    
    init() {
        setupSolana()
    }
    
    func setupSolana() {
        let secretKey: [UInt8] = [146,86,159,181,4,99,163,205,167,151,42,87,98,155,156,128,147,66,107,236,179,15,4,21,222,110,129,152,213,64,18,248,193,229,132,86,10,231,233,6,175,101,4,202,92,87,11,200,43,88,39,46,133,24,55,128,169,17,220,172,152,73,222,46]
        
        Task {
            do {
                keyPair = try KeyPair(secretKey: Data(secretKey))
                print("✅ Wallet: \(keyPair?.publicKey.base58EncodedString ?? "Unknown")")
                await updateBalance()
            } catch {
                print("❌ Keypair Error: \(error)")
                await MainActor.run { self.statusMessage = "Wallet Error" }
            }
        }
    }
    
    @MainActor
    func updateBalance() async {
        guard let keyPair = keyPair else { return }
        do {
            let bal = try await rpcGetBalance(account: keyPair.publicKey.base58EncodedString)
            self.balance = Double(bal) / 1_000_000_000.0
            
            // Also fetch vault balance
            let vaultBal = try await rpcGetBalance(account: vaultPDA)
            self.vaultBalance = Double(vaultBal) / 1_000_000_000.0
            
            self.statusMessage = "Connected"
            print("✅ Wallet: \(self.balance) SOL | Vault: \(self.vaultBalance) SOL")
        } catch {
            self.statusMessage = "Balance Error"
            print("❌ Balance Error: \(error)")
        }
    }
    
    func depositSOL(amount: Double, teamId: UInt64) {
        Task { await performDeposit(amount: amount, teamId: teamId) }
    }
    
    func placeBid(lamports: UInt64, taskId: UInt64, teamId: UInt64) {
        Task { await performBid(lamports: lamports, taskId: taskId, teamId: teamId) }
    }
    
    func payoutTask(taskId: UInt64, teamId: UInt64) {
        Task { await performPayout(taskId: taskId, teamId: teamId) }
    }
    
    // Full flow functions
    func createTask(taskId: UInt64, rewardLamports: UInt64, teamId: UInt64, auctionDurationSeconds: Int64 = 30) async -> Bool {
        return await performCreateTask(taskId: taskId, rewardLamports: rewardLamports, teamId: teamId, auctionDurationSeconds: auctionDurationSeconds)
    }
    
    func finalizeAuction(taskId: UInt64, teamId: UInt64) {
        Task { await performFinalizeAuction(taskId: taskId, teamId: teamId) }
    }
    
    func markComplete(taskId: UInt64, teamId: UInt64) {
        Task { await performMarkComplete(taskId: taskId, teamId: teamId) }
    }
    
    func completeAndPayout(taskId: UInt64, teamId: UInt64) {
        Task { await performCompleteAndPayout(taskId: taskId, teamId: teamId) }
    }
    
    // MARK: - Raw RPC Calls (bypass broken library)
    
    private func rpcGetBalance(account: String) async throws -> UInt64 {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getBalance",
            "params": [account]
        ]
        let result = try await makeRPCCall(body: body)
        guard let value = (result["result"] as? [String: Any])?["value"] as? UInt64 else {
            throw NSError(domain: "RPC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid balance response"])
        }
        return value
    }
    
    private func rpcGetLatestBlockhash() async throws -> String {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getLatestBlockhash",
            "params": []
        ]
        let result = try await makeRPCCall(body: body)
        guard let blockhash = ((result["result"] as? [String: Any])?["value"] as? [String: Any])?["blockhash"] as? String else {
            throw NSError(domain: "RPC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid blockhash response"])
        }
        return blockhash
    }
    
    private func rpcSendTransaction(base64Tx: String) async throws -> String {
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "sendTransaction",
            "params": [base64Tx, ["encoding": "base64", "skipPreflight": true]]
        ]
        let result = try await makeRPCCall(body: body)
        if let error = result["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw NSError(domain: "RPC", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard let signature = result["result"] as? String else {
            throw NSError(domain: "RPC", code: -1, userInfo: [NSLocalizedDescriptionKey: "No signature returned"])
        }
        return signature
    }
    
    private func makeRPCCall(body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: endpointURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "RPC", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        return json
    }
    
    // MARK: - Transactions
    
    @MainActor
    private func performDeposit(amount: Double, teamId: UInt64) async {
        guard let keyPair = keyPair else { return }
        isProcessing = true
        statusMessage = "Depositing..."
        
        do {
            let lamports = UInt64(amount * 1_000_000_000)
            let programKey = try PublicKey(string: programId)
            
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let (vaultPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["vault".data(using: .utf8)!, teamPDA.data],
                programId: programKey
            )
            
            print("📍 Team PDA: \(teamPDA.base58EncodedString)")
            print("📍 Vault PDA: \(vaultPDA.base58EncodedString)")
            
            var data = Data([242, 35, 198, 137, 82, 225, 242, 182])
            data.append(contentsOf: withUnsafeBytes(of: lamports.littleEndian) { Array($0) })
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: vaultPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: false),
                    AccountMeta(publicKey: SystemProgram.id, isSigner: false, isWritable: false)
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            // Get blockhash via raw RPC
            let blockhash = try await rpcGetLatestBlockhash()
            print("📦 Blockhash: \(blockhash)")
            
            // Build transaction
            var transaction = Transaction(
                instructions: [instruction],
                recentBlockhash: blockhash,
                feePayer: keyPair.publicKey
            )
            try transaction.sign(signers: [keyPair])
            
            let serialized = try transaction.serialize()
            let base64Tx = serialized.base64EncodedString()
            
            // Send via raw RPC
            let txId = try await rpcSendTransaction(base64Tx: base64Tx)
            statusMessage = "Success! Tx: \(txId.prefix(8))..."
            print("✅ Transaction: \(txId)")
            
            // Wait 2 seconds for transaction to confirm before allowing another
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await updateBalance()
            
        } catch {
            statusMessage = "Deposit Failed: \(error.localizedDescription)"
            print("❌ Deposit Error: \(error)")
        }
        isProcessing = false
    }
    
    @MainActor
    private func performBid(lamports: UInt64, taskId: UInt64, teamId: UInt64) async {
        guard let keyPair = keyPair else { return }
        isProcessing = true
        statusMessage = "Placing Bid..."
        
        do {
            let programKey = try PublicKey(string: programId)
            
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let (taskPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            )
            
            var data = Data([238, 77, 148, 91, 200, 151, 92, 146])
            data.append(contentsOf: withUnsafeBytes(of: lamports.littleEndian) { Array($0) })
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: false)
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            let blockhash = try await rpcGetLatestBlockhash()
            var transaction = Transaction(
                instructions: [instruction],
                recentBlockhash: blockhash,
                feePayer: keyPair.publicKey
            )
            try transaction.sign(signers: [keyPair])
            
            let serialized = try transaction.serialize()
            let base64Tx = serialized.base64EncodedString()
            let txId = try await rpcSendTransaction(base64Tx: base64Tx)
            
            statusMessage = "Bid Placed! Tx: \(txId.prefix(8))..."
            print("✅ Bid Transaction: \(txId)")
            
        } catch {
            statusMessage = "Bid Failed: \(error.localizedDescription)"
            print("❌ Bid Error: \(error)")
        }
        isProcessing = false
    }
    
    @MainActor
    private func performPayout(taskId: UInt64, teamId: UInt64) async {
        guard let keyPair = keyPair else { return }
        isProcessing = true
        statusMessage = "Processing payout..."
        
        do {
            let programKey = try PublicKey(string: programId)
            
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let (vaultPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["vault".data(using: .utf8)!, teamPDA.data],
                programId: programKey
            )
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let (taskPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            )
            
            print("📍 Payout - Team: \(teamPDA.base58EncodedString)")
            print("📍 Payout - Task: \(taskPDA.base58EncodedString)")
            print("📍 Payout - Vault: \(vaultPDA.base58EncodedString)")
            
            // payout_task discriminator: [186, 110, 58, 100, 243, 131, 192, 97]
            let data = Data([186, 110, 58, 100, 243, 131, 192, 97])
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: vaultPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: false, isWritable: true), // recipient
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: false), // authority
                    AccountMeta(publicKey: SystemProgram.id, isSigner: false, isWritable: false)
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            let blockhash = try await rpcGetLatestBlockhash()
            var transaction = Transaction(
                instructions: [instruction],
                recentBlockhash: blockhash,
                feePayer: keyPair.publicKey
            )
            try transaction.sign(signers: [keyPair])
            
            let serialized = try transaction.serialize()
            let base64Tx = serialized.base64EncodedString()
            let txId = try await rpcSendTransaction(base64Tx: base64Tx)
            
            statusMessage = "Payout Success! Tx: \(txId.prefix(8))..."
            print("✅ Payout Transaction: \(txId)")
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await updateBalance()
            
        } catch {
            statusMessage = "Payout Failed: \(error.localizedDescription)"
            print("❌ Payout Error: \(error)")
        }
        isProcessing = false
    }
    
    @MainActor
    private func performCreateTask(taskId: UInt64, rewardLamports: UInt64, teamId: UInt64, auctionDurationSeconds: Int64) async -> Bool {
        guard let keyPair = keyPair else { return false }
        isProcessing = true
        statusMessage = "Creating Task..."
        
        do {
            let programKey = try PublicKey(string: programId)
            
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let (taskPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            )
            
            // create_task_auction: [67, 18, 222, 59, 237, 85, 252, 236]
            var data = Data([67, 18, 222, 59, 237, 85, 252, 236])
            data.append(contentsOf: withUnsafeBytes(of: taskId.littleEndian) { Array($0) })
            data.append(contentsOf: withUnsafeBytes(of: rewardLamports.littleEndian) { Array($0) })
            let now = Int64(Date().timeIntervalSince1970)
            let endTs = now + auctionDurationSeconds
            data.append(contentsOf: withUnsafeBytes(of: endTs.littleEndian) { Array($0) })
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: true),
                    AccountMeta(publicKey: SystemProgram.id, isSigner: false, isWritable: false)
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            let blockhash = try await rpcGetLatestBlockhash()
            var transaction = Transaction(instructions: [instruction], recentBlockhash: blockhash, feePayer: keyPair.publicKey)
            try transaction.sign(signers: [keyPair])
            
            let serialized = try transaction.serialize()
            let txId = try await rpcSendTransaction(base64Tx: serialized.base64EncodedString())
            
            statusMessage = "Created Task! Tx: \(txId.prefix(8))..."
            print("✅ Created Task: \(txId)")
            isProcessing = false
            return true
        } catch {
            statusMessage = "Create Task Failed"
            print("❌ Create Task Error: \(error)")
            isProcessing = false
            return false
        }
    }
    
    @MainActor
    private func performFinalizeAuction(taskId: UInt64, teamId: UInt64) async {
        guard let keyPair = keyPair else { return }
        print("⏳ Finalizing...")
        do {
            let programKey = try PublicKey(string: programId)
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let (taskPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            )
            
            // finalize_auction: [108, 194, 150, 192, 53, 203, 218, 35]
            let data = Data([108, 194, 150, 192, 53, 203, 218, 35])
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true)
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            let blockhash = try await rpcGetLatestBlockhash()
            var transaction = Transaction(instructions: [instruction], recentBlockhash: blockhash, feePayer: keyPair.publicKey)
            try transaction.sign(signers: [keyPair])
            let serialized = try transaction.serialize()
            let txId = try await rpcSendTransaction(base64Tx: serialized.base64EncodedString())
            print("✅ Finalized: \(txId)")
        } catch {
            print("⚠️ Finalize Skipped: \(error)") // Might already be finalized or open
        }
    }
    
    @MainActor
    private func performAssignTask(taskId: UInt64, teamId: UInt64) async {
        guard let keyPair = keyPair else { return }
        print("⏳ Assigning...")
        do {
            let programKey = try PublicKey(string: programId)
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let (taskPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            )
            
            // assign_task: [240, 109, 238, 59, 214, 189, 78, 137]
            let data = Data([240, 109, 238, 59, 214, 189, 78, 137])
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: false, isWritable: false), // assignee (self)
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: false)  // authority
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            let blockhash = try await rpcGetLatestBlockhash()
            var transaction = Transaction(instructions: [instruction], recentBlockhash: blockhash, feePayer: keyPair.publicKey)
            try transaction.sign(signers: [keyPair])
            let serialized = try transaction.serialize()
            let txId = try await rpcSendTransaction(base64Tx: serialized.base64EncodedString())
            print("✅ Assigned: \(txId)")
        } catch {
            print("⚠️ Assign Skipped: \(error)")
        }
    }
    
    @MainActor
    private func performMarkComplete(taskId: UInt64, teamId: UInt64) async {
        guard let keyPair = keyPair else { return }
        print("⏳ Marking Complete...")
        do {
            let programKey = try PublicKey(string: programId)
            let teamIdBytes = withUnsafeBytes(of: teamId.littleEndian) { Array($0) }
            let (teamPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["team".data(using: .utf8)!, keyPair.publicKey.data, Data(teamIdBytes)],
                programId: programKey
            )
            let taskIdBytes = withUnsafeBytes(of: taskId.littleEndian) { Array($0) }
            let (taskPDA, _) = try PublicKey.findProgramAddress(
                seeds: ["task".data(using: .utf8)!, teamPDA.data, Data(taskIdBytes)],
                programId: programKey
            )
            
            // mark_complete: [72, 54, 142, 60, 245, 34, 161, 88]
            let data = Data([72, 54, 142, 60, 245, 34, 161, 88])
            
            let instruction = TransactionInstruction(
                keys: [
                    AccountMeta(publicKey: teamPDA, isSigner: false, isWritable: false),
                    AccountMeta(publicKey: taskPDA, isSigner: false, isWritable: true),
                    AccountMeta(publicKey: keyPair.publicKey, isSigner: true, isWritable: false) // assignee
                ],
                programId: programKey,
                data: [UInt8](data)
            )
            
            let blockhash = try await rpcGetLatestBlockhash()
            var transaction = Transaction(instructions: [instruction], recentBlockhash: blockhash, feePayer: keyPair.publicKey)
            try transaction.sign(signers: [keyPair])
            let serialized = try transaction.serialize()
            let txId = try await rpcSendTransaction(base64Tx: serialized.base64EncodedString())
            print("✅ Marked Complete: \(txId)")
        } catch {
            print("⚠️ Mark Complete Skipped: \(error)")
        }
    }
    
    @MainActor
    private func performCompleteAndPayout(taskId: UInt64, teamId: UInt64) async {
        isProcessing = true
        statusMessage = "Finalizing..."
        await performFinalizeAuction(taskId: taskId, teamId: teamId)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        statusMessage = "Assigning..."
        await performAssignTask(taskId: taskId, teamId: teamId)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        statusMessage = "Completing..."
        await performMarkComplete(taskId: taskId, teamId: teamId)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        statusMessage = "Paying out..."
        await performPayout(taskId: taskId, teamId: teamId)
        
        isProcessing = false
    }
}
