import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { TaskfiEscrow } from "../target/types/taskfi_escrow";

describe("taskfi_escrow (Task lifecycle)", () => {
  anchor.setProvider(anchor.AnchorProvider.env());
  const provider = anchor.getProvider() as anchor.AnchorProvider;
  const program = anchor.workspace.TaskfiEscrow as Program<TaskfiEscrow>;

  it("initialize -> deposit -> create -> assign -> complete -> payout_task", async () => {
    const authority = provider.wallet.publicKey;

    const teamId = new anchor.BN(1);
    const taskId = new anchor.BN(1);

    // Team PDA (matches Rust seeds: ["team", authority, team_id_le])
    const [teamPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [
        Buffer.from("team"),
        authority.toBuffer(),
        teamId.toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    );

    // Vault PDA (matches Rust seeds: ["vault", team_pubkey])
    const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault"), teamPda.toBuffer()],
      program.programId
    );

    // Task PDA (matches Rust seeds: ["task", team_pubkey, task_id_le])
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

    // 2) deposit into vault (0.005 SOL)
    const depositLamports = new anchor.BN(5_000_000);
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

    // 3) create_task with reward 0.002 SOL
    const rewardLamports = new anchor.BN(2_000_000);
    await program.methods
      .createTask(taskId, rewardLamports)
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      } as any)
      .rpc();

    // 4) assign_task to authority (MVP)
    await program.methods
      .assignTask()
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        assignee: authority,
        authority,
      } as any)
      .rpc();

    // 5) mark_complete as assignee
    await program.methods
      .markComplete()
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        assignee: authority,
      } as any)
      .rpc();

    // 6) payout_task (vault -> assignee)
    await program.methods
      .payoutTask()
      .accountsPartial({
        team: teamPda,
        task: taskPda,
        vault: vaultPda,
        recipient: authority,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      } as any)
      .rpc();

    const vaultAfterPayout = await provider.connection.getBalance(vaultPda);
    console.log("Vault after payout:", vaultAfterPayout);

    // Fetch the task account to verify status
    const taskAcct = await program.account.task.fetch(taskPda);
    console.log("Task status:", taskAcct.status);

    // Status Paid = 3 (per your enum order)
    if (taskAcct.status !== 3) {
      throw new Error(`Expected task status 3 (Paid), got ${taskAcct.status}`);
    }

    // Vault should decrease by rewardLamports
    const expected = vaultAfterDeposit - rewardLamports.toNumber();
    if (vaultAfterPayout !== expected) {
      throw new Error(
        `Vault mismatch. Expected ${expected}, got ${vaultAfterPayout}`
      );
    }
  });
});
