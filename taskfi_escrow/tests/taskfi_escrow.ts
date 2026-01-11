import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { TaskfiEscrow } from "../target/types/taskfi_escrow";

describe("taskfi_escrow", () => {
  anchor.setProvider(anchor.AnchorProvider.env());
  const provider = anchor.getProvider() as anchor.AnchorProvider;
  const program = anchor.workspace.TaskfiEscrow as Program<TaskfiEscrow>;

  it("initialize -> deposit -> payout", async () => {
    const authority = provider.wallet.publicKey;
    const teamId = new anchor.BN(1);

    // Derive Team PDA (for balance checks + clarity)
    const [teamPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [
        Buffer.from("team"),
        authority.toBuffer(),
        teamId.toArrayLike(Buffer, "le", 8),
      ],
      program.programId
    );

    // Derive Vault PDA (for balance checks)
    const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
      [Buffer.from("vault"), teamPda.toBuffer()],
      program.programId
    );

    // 1) Initialize team
    // Use accountsPartial to avoid TS complaining about PDA-resolved accounts.
    await program.methods
      .initializeTeam(teamId)
      .accountsPartial({
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
        team: teamPda,
        vault: vaultPda,
      })
      .rpc();

    // 2) Deposit a tiny amount
    const depositLamports = new anchor.BN(5_000_000); // 0.001 SOL
    await program.methods
      .deposit(depositLamports)
      .accountsPartial({
        team: teamPda,
        depositor: authority,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
        // vault intentionally omitted or included - partial allows either
        vault: vaultPda,
      })
      .rpc();

    const vaultBalAfterDeposit = await provider.connection.getBalance(vaultPda);
    console.log("Vault balance after deposit:", vaultBalAfterDeposit);

    // 3) Payout
    const recipient = anchor.web3.Keypair.generate();
    const payoutLamports = new anchor.BN(2_000_000); // 0.0001 SOL

    await program.methods
      .payout(payoutLamports)
      .accountsPartial({
        team: teamPda,
        vault: vaultPda,
        recipient: recipient.publicKey,
        authority,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();

    const vaultBalAfterPayout = await provider.connection.getBalance(vaultPda);
    const recipientBal = await provider.connection.getBalance(recipient.publicKey);

    console.log("Vault balance after payout:", vaultBalAfterPayout);
    console.log("Recipient balance:", recipientBal);

    if (recipientBal !== payoutLamports.toNumber()) {
      throw new Error(
        `Recipient did not receive expected payout. Expected ${payoutLamports.toNumber()}, got ${recipientBal}`
      );
    }
  });
});
