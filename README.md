# Taski

> A native decentralized marketplace that bridges everyday household tasks with the Solana blockchain, automatically verifying work before releasing payment.

## What it does

Taski helps roommates and households manage chores with blockchain-backed accountability. Post household tasks (like "Take out the trash" or "Do the dishes") with a USD bounty that gets locked in a smart contract vault. Your roommates can claim tasks, complete them, and submit photo proof. Google Gemini AI automatically verifies the work was done, and funds are instantly released to their wallet—no more "I'll do it later" excuses.

## ✨ Features

- **Decentralized Marketplace**: Post chores with USD bounties, automatically converted to SOL
- **Smart Vault Escrow**: Funds securely locked in blockchain vaults until task completion
- **AI Verification**: Google Gemini analyzes photos to verify task completion
- **Instant Crypto Payout**: Automatic fund release upon AI verification

## 🛠️ Tech Stack

- **Frontend**: SwiftUI (iOS)
- **Blockchain**: Solana (Devnet), Anchor (Rust)
- **AI**: Google Gemini API
- **Custom Solana Service**: Raw transaction serialization, PDA calculations

## 🚀 Getting Started

### Prerequisites
- Xcode 15+
- Google Gemini API Key
- Anchor Framework (for smart contracts)

### Setup

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/Taski.git
   cd Taski
   ```

2. Configure iOS app
   - Open `DeltaHacks2026.xcodeproj` in Xcode
   - Copy `Secrets-Example.plist` to `Secrets.plist`
   - Add your Gemini API key:
     ```xml
     <key>GEMINI_API_KEY</key>
     <string>YOUR_API_KEY_HERE</string>
     ```

3. Deploy smart contract (optional)
   ```bash
   cd taskfi_escrow
   yarn install
   anchor build
   anchor deploy
   ```

4. Run the app in Xcode (⌘R)

## 🛠️ Built With

- [Anchor](https://www.anchor-lang.com) - Solana smart contracts
- [Gemini](https://ai.google.dev) - AI image verification
- [Solana](https://solana.com) - Blockchain
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - iOS framework

---

Built for DeltaHacks 2026
