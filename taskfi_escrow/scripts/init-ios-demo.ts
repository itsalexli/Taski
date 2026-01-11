import * as anchor from "@coral-xyz/anchor";
import * as bip39 from "bip39";
import { derivePath } from "ed25519-hd-key";
import { Connection, Keypair, PublicKey, SystemProgram } from "@solana/web3.js";
import { Program } from "@coral-xyz/anchor";
import { TaskfiEscrow } from "../target/types/taskfi_escrow";
import fs from "fs";

const ENDPOINT = "http://172.18.78.52:8899";
const MNEMONIC = "route clerk illness curve couple divorce hello verify visual senior moral cover";

// Derive keypair from iOS mnemonic
const seed = bip39.mnemonicToSeedSync(MNEMONIC);
const derivedSeed = derivePath("m/44'/501'/0'/0'", seed.toString("hex")).key;
const iosKeypair = Keypair.fromSeed(derivedSeed);

console.log("=== iOS Demo Setup ===");
console.log("iOS Wallet:", iosKeypair.publicKey.toBase58());

const connection = new Connection(ENDPOINT, "confirmed");
const wallet = new anchor.Wallet(iosKeypair);
const provider = new anchor.AnchorProvider(connection, wallet, {});
anchor.setProvider(provider);

const idl = JSON.parse(fs.readFileSync("./target/idl/taskfi_escrow.json", "utf8"));
const program = new anchor.Program(idl, provider) as Program<TaskfiEscrow>;

const teamId = new anchor.BN(1);
const authority = iosKeypair.publicKey;

const [teamPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("team"), authority.toBuffer(), teamId.toArrayLike(Buffer, "le", 8)],
    program.programId
);
const [vaultPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("vault"), teamPda.toBuffer()],
    program.programId
);

console.log("Team PDA:", teamPda.toBase58());
console.log("Vault PDA:", vaultPda.toBase58());

async function main() {
    const bal = await connection.getBalance(authority);
    console.log("iOS Wallet Balance:", bal / 1e9, "SOL");

    const teamAccount = await connection.getAccountInfo(teamPda);
    if (teamAccount) {
        console.log("✅ Team already initialized!");
    } else {
        console.log("📦 Initializing team...");
        const tx = await program.methods
            .initializeTeam(teamId)
            .accountsPartial({
                team: teamPda,
                vault: vaultPda,
                authority,
                systemProgram: SystemProgram.programId,
            } as any)
            .rpc();
        console.log("✅ Team initialized! Tx:", tx);
    }

    const vaultBal = await connection.getBalance(vaultPda);
    console.log("💰 Vault Balance:", vaultBal / 1e9, "SOL");
}

main().catch(console.error);
