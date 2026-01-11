import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { TaskfiEscrow } from "../target/types/taskfi_escrow";

// Setup a task that's ready for payout from iOS app
describe("Setup task for iOS payout demo", () => {
    anchor.setProvider(anchor.AnchorProvider.env());
    const provider = anchor.getProvider() as anchor.AnchorProvider;
    const program = anchor.workspace.TaskfiEscrow as Program<TaskfiEscrow>;

    it("creates a task ready for iOS payout", async () => {
        const authority = provider.wallet.publicKey;
        const teamId = new anchor.BN(1);
        const taskId = new anchor.BN(3); // Use task ID 3 for fresh demo

        // Team PDA (should already exist from previous tests)
        const [teamPda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("team"), authority.toBuffer(), teamId.toArrayLike(Buffer, "le", 8)],
            program.programId
        );

        // Vault PDA
        const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("vault"), teamPda.toBuffer()],
            program.programId
        );

        // Task PDA
        const [taskPda] = anchor.web3.PublicKey.findProgramAddressSync(
            [Buffer.from("task"), teamPda.toBuffer(), taskId.toArrayLike(Buffer, "le", 8)],
            program.programId
        );

        console.log("Authority:", authority.toBase58());
        console.log("Team PDA:", teamPda.toBase58());
        console.log("Vault PDA:", vaultPda.toBase58());
        console.log("Task PDA:", taskPda.toBase58());

        // Check vault balance
        const vaultBal = await provider.connection.getBalance(vaultPda);
        console.log("\nVault balance:", vaultBal / 1e9, "SOL");

        if (vaultBal < 100000) {
            console.log("Vault needs more SOL. Depositing 0.01 SOL...");
            await program.methods
                .deposit(new anchor.BN(10_000_000)) // 0.01 SOL
                .accountsPartial({
                    team: teamPda,
                    vault: vaultPda,
                    depositor: authority,
                    authority,
                    systemProgram: anchor.web3.SystemProgram.programId,
                } as any)
                .rpc();
        }

        // Create task with short auction (ends in 2 seconds)
        const reserveReward = new anchor.BN(1_000_000); // 0.001 SOL reward
        const nowTs = Math.floor(Date.now() / 1000);
        const auctionEndTs = new anchor.BN(nowTs + 2);

        try {
            await program.methods
                .createTaskAuction(taskId, reserveReward, auctionEndTs)
                .accountsPartial({
                    team: teamPda,
                    task: taskPda,
                    authority,
                    systemProgram: anchor.web3.SystemProgram.programId,
                } as any)
                .rpc();
            console.log("Task created!");
        } catch (e: any) {
            if (e.message?.includes("already in use")) {
                console.log("Task already exists, continuing...");
            } else {
                throw e;
            }
        }

        // Wait for auction to end
        console.log("Waiting for auction to end...");
        await new Promise(r => setTimeout(r, 3000));

        // Finalize auction (assigns to default since no bids)
        try {
            await program.methods
                .finalizeAuction()
                .accountsPartial({ team: teamPda, task: taskPda } as any)
                .rpc();
            console.log("Auction finalized!");
        } catch (e: any) {
            console.log("Finalize skipped:", e.message?.substring(0, 50));
        }

        // Assign task to ourselves (authority)
        try {
            await program.methods
                .assignTask()
                .accountsPartial({
                    team: teamPda,
                    task: taskPda,
                    assignee: authority,
                    authority,
                } as any)
                .rpc();
            console.log("Task assigned to authority!");
        } catch (e: any) {
            console.log("Assign skipped:", e.message?.substring(0, 50));
        }

        // Mark complete (as the assignee)
        try {
            await program.methods
                .markComplete()
                .accountsPartial({
                    team: teamPda,
                    task: taskPda,
                    assignee: authority,
                } as any)
                .rpc();
            console.log("Task marked complete!");
        } catch (e: any) {
            console.log("Mark complete skipped:", e.message?.substring(0, 50));
        }

        // Fetch task status
        const taskAcct = await program.account.task.fetch(taskPda);
        console.log("\n=== Task Ready for iOS Payout ===");
        console.log("Task ID:", taskId.toString());
        console.log("Status:", taskAcct.status, "(4 = Paid, 3 = Completed)");
        console.log("Assignee:", taskAcct.assignee.toBase58());
        console.log("Reward:", Number(taskAcct.rewardLamports || 0) / 1e9, "SOL");
        console.log("\nNow run iOS app and press Complete on a task!");
    });
});
