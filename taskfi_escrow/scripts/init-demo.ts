import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { TaskfiEscrow } from "../target/types/taskfi_escrow";
import fs from "fs";

const walletPath = process.env.HOME + "/.config/solana/id.json";
const keypairData = JSON.parse(fs.readFileSync(walletPath, "utf8"));
const keypair = anchor.web3.Keypair.fromSecretKey(Uint8Array.from(keypairData));

// Connect to YOUR local validator (the one iOS app uses)
const connection = new anchor.web3.Connection("http://172.18.78.52:8899", "confirmed");
const wallet = new anchor.Wallet(keypair);
const provider = new anchor.AnchorProvider(connection, wallet, {});
anchor.setProvider(provider);

const idl = JSON.parse(fs.readFileSync("./target/idl/taskfi_escrow.json", "utf8"));
const program = new anchor.Program(idl, provider) as Program<TaskfiEscrow>;

const teamId = new anchor.BN(1);
const authority = wallet.publicKey;

const [teamPda] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("team"), authority.toBuffer(), teamId.toArrayLike(Buffer, "le", 8)],
  program.programId
);
const [vaultPda] = anchor.web3.PublicKey.findProgramAddressSync(
  [Buffer.from("vault"), teamPda.toBuffer()],
  program.programId
);

console.log("=== Demo Setup Script ===");
console.log("Authority:", authority.toBase58());
console.log("Team PDA:", teamPda.toBase58());
console.log("Vault PDA:", vaultPda.toBase58());
console.log("");

async function main() {
  try {
    // Check if team already exists
    const teamAccount = await connection.getAccountInfo(teamPda);
    if (teamAccount) {
      console.log("✅ Team already exists!");
    } else {
      console.log("📦 Initializing team...");
      const tx = await program.methods
        .initializeTeam(teamId)
        .accountsPartial({
          team: teamPda,
          vault: vaultPda,
          authority,
          systemProgram: anchor.web3.SystemProgram.programId,
        } as any)
        .rpc();
      console.log("✅ Team initialized! Tx:", tx);
    }

    // Show vault balance
    const vaultBal = await connection.getBalance(vaultPda);
    console.log("💰 Vault balance:", vaultBal / 1_000_000_000, "SOL");

    // Show authority balance
    const authBal = await connection.getBalance(authority);
    console.log("👤 Authority balance:", authBal / 1_000_000_000, "SOL");

  } catch (e: any) {
    console.error("❌ Error:", e.message);
  }
}

main();
