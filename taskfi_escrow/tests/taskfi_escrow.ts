import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { TaskfiEscrow } from "../target/types/taskfi_escrow";

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

describe("taskfi_escrow (Auction lifecycle)", () => {
  anchor.setProvider(anchor.AnchorProvider.env());
  const provider = anchor.getProvider() as anchor.AnchorProvider;
  const program = anchor.workspace.TaskfiEscrow as Program<TaskfiEscrow>;

  it("initialize -> deposit -> create auction -> bid -> finalize -> complete -> payout", async () => {
    const authority = provider.wallet.publicKey;

    const teamId = new anchor.BN(1);
    const taskId = new anchor.BN(1);

    // Team PDA
    const [teamPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [
        Buffer.from("team"),
        authority.toBuffer(),
        teamId.toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    );

    // Vault PDA
    const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault"), teamPda.toBuffer()],
      program.programId
    );

    // Task PDA
    const [taskPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [
        Buffer.from("task"),
        teamPda.toBuffer(),
        taskId.toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    );

    // 1) initialize_team
    await program.methods
      .initializeTeam(teamId)
      .accountsPartial({
        team: teamPda,
        vault: vaultPda,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      } as any)
      .rpc();

    // 2) deposit into vault
    const depositLamports = new anchor.BN(5_000_000); // 0.005 SOL
    await program.methods
      .deposit(depositLamports)
      .accountsPartial({
        team: teamPda,
        vault: vaultPda,
        depositor: authority,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      } as any)
      .rpc();

    const vaultAfterDeposit = await provider.connection.getBalance(vaultPda);
    console.log("Vault after deposit:", vaultAfterDeposit);

    // 3) create_task_auction (reserve reward + end time soon)
    const reserveReward = new anchor.BN(2_000_000); // suggested reward / cap
    const nowTs = Math.floor(Date.now() / 1000);
    const auctionEndTs = new anchor.BN(nowTs + 5); // 5 seconds for test

    await program.methods
      .createTaskAuction(taskId, reserveReward, auctionEndTs)
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      } as any)
      .rpc();

    // Create two bidder wallets
    const bidderA = anchor.web3.Keypair.generate();
    const bidderB = anchor.web3.Keypair.generate();

    // Fund bidders for fees (local validator)
    await provider.connection.requestAirdrop(bidderA.publicKey, 1_000_000_000);
    await provider.connection.requestAirdrop(bidderB.publicKey, 1_000_000_000);

    // 4) place_bid A: 1_900_000
    await program.methods
      .placeBid(new anchor.BN(1_900_000))
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        bidder: bidderA.publicKey,
      } as any)
      .signers([bidderA])
      .rpc();

    // 5) place_bid B: 1_500_000 (lower, should win)
    const winningBid = new anchor.BN(1_500_000);
    await program.methods
      .placeBid(winningBid)
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        bidder: bidderB.publicKey,
      } as any)
      .signers([bidderB])
      .rpc();

    // wait for auction to end
    await sleep(6000);

    // 6) finalize_auction (anyone can call; use authority)
    await program.methods
      .finalizeAuction()
      .accountsPartial({
        team: teamPda,
        task: taskPda,
      } as any)
      .rpc();

    // Fetch task and confirm assignment
    let taskAcct = await program.account.task.fetch(taskPda);
    console.log("After finalize: status =", taskAcct.status);
    console.log("Assignee =", taskAcct.assignee.toBase58());
    console.log("Reward =", taskAcct.rewardLamports?.toString?.() ?? taskAcct.rewardLamports);

    if (taskAcct.assignee.toBase58() !== bidderB.publicKey.toBase58()) {
      throw new Error("Auction winner mismatch: expected bidderB to be assignee");
    }

    // 7) mark_complete by the assignee (bidderB)
    await program.methods
      .markComplete()
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        assignee: bidderB.publicKey,
      } as any)
      .signers([bidderB])
      .rpc();

    // 8) payout_task (authority triggers payout, recipient is assignee)
    await program.methods
      .payoutTask()
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        vault: vaultPda,
        recipient: bidderB.publicKey,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      } as any)
      .rpc();

    const vaultAfterPayout = await provider.connection.getBalance(vaultPda);
    console.log("Vault after payout:", vaultAfterPayout);

    taskAcct = await program.account.task.fetch(taskPda);
    console.log("Final task status:", taskAcct.status);

    // With enum: Open=0, Bidding=1, Assigned=2, Completed=3, Paid=4
    if (taskAcct.status !== 4) {
      throw new Error(`Expected task status 4 (Paid), got ${taskAcct.status}`);
    }

    const expectedVault = vaultAfterDeposit - winningBid.toNumber();
    if (vaultAfterPayout !== expectedVault) {
      throw new Error(
        `Vault mismatch. Expected ${expectedVault}, got ${vaultAfterPayout}`
      );
    }

    const bidderBBal = await provider.connection.getBalance(bidderB.publicKey);
    console.log("BidderB balance:", bidderBBal);
  });
});
