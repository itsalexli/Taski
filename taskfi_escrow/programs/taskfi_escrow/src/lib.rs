use anchor_lang::prelude::*;
use anchor_lang::solana_program::{program::invoke, system_instruction};

declare_id!("TrSvGRr4F3aVXvyGMKQWaWYwFHawWcDaiL5WqUL6DVU");

#[program]
pub mod taskfi_escrow {
    use super::*;

    /// Creates a Team account and records the PDA bump for the vault.
    pub fn initialize_team(ctx: Context<InitializeTeam>, team_id: u64) -> Result<()> {
        let team = &mut ctx.accounts.team;
        team.authority = ctx.accounts.authority.key();
        team.team_id = team_id;
        team.vault_bump = ctx.bumps.vault;
        Ok(())
    }

    /// Deposits SOL from depositor -> vault PDA (escrow).
    pub fn deposit(ctx: Context<Deposit>, amount_lamports: u64) -> Result<()> {
        require!(amount_lamports > 0, EscrowError::InvalidAmount);

        // Transfer lamports from depositor wallet to vault PDA
        let ix = system_instruction::transfer(
            &ctx.accounts.depositor.key(),
            &ctx.accounts.vault.key(),
            amount_lamports,
        );

        invoke(
            &ix,
            &[
                ctx.accounts.depositor.to_account_info(),
                ctx.accounts.vault.to_account_info(),
                ctx.accounts.system_program.to_account_info(),
            ],
        )?;

        Ok(())
    }

        /// Pays SOL out of the vault PDA to a recipient.
    /// MVP rule: only the team authority can trigger payout.
    pub fn payout(ctx: Context<Payout>, amount_lamports: u64) -> Result<()> {
        require!(amount_lamports > 0, EscrowError::InvalidAmount);

        // Optional safety: ensure vault has enough lamports
        let vault_lamports = ctx.accounts.vault.to_account_info().lamports();
        require!(vault_lamports >= amount_lamports, EscrowError::InsufficientVaultFunds);

        // PDA seeds used to "sign" as the vault
        let team_key = ctx.accounts.team.key();
        let seeds: &[&[u8]] = &[
            b"vault",
            team_key.as_ref(),
            &[ctx.accounts.team.vault_bump],
        ];
        let signer_seeds: &[&[&[u8]]] = &[seeds];

        // Transfer lamports from vault PDA -> recipient
        let ix = system_instruction::transfer(
            &ctx.accounts.vault.key(),
            &ctx.accounts.recipient.key(),
            amount_lamports,
        );

        anchor_lang::solana_program::program::invoke_signed(
            &ix,
            &[
                ctx.accounts.vault.to_account_info(),
                ctx.accounts.recipient.to_account_info(),
                ctx.accounts.system_program.to_account_info(),
            ],
            signer_seeds,
        )?;

        Ok(())
    }
}

#[derive(Accounts)]
#[instruction(team_id: u64)]
pub struct InitializeTeam<'info> {
    /// Team PDA: stores authority + team_id + vault bump.
    #[account(
        init,
        payer = authority,
        space = 8 + Team::INIT_SPACE,
        seeds = [b"team", authority.key().as_ref(), &team_id.to_le_bytes()],
        bump
    )]
    pub team: Account<'info, Team>,

    /// CHECK: This is the team vault PDA. It holds SOL (lamports) and does not store data,
    /// so we don't need to deserialize it into a typed account. We verify it via PDA seeds.
    #[account(
        mut,
        seeds = [b"vault", team.key().as_ref()],
        bump
    )]
    pub vault: UncheckedAccount<'info>,


    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    /// The Team account (must belong to authority).
    #[account(
        has_one = authority
    )]
    pub team: Account<'info, Team>,

    /// CHECK: This is the team vault PDA. It holds SOL (lamports) and does not store data,
    /// so we don't need to deserialize it into a typed account. We verify it via PDA seeds + bump.
    #[account(
        mut,
        seeds = [b"vault", team.key().as_ref()],
        bump = team.vault_bump
    )]
    pub vault: UncheckedAccount<'info>,


    #[account(mut)]
    pub depositor: Signer<'info>,

    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Payout<'info> {
    /// The Team account (authority must match team.authority).
    #[account(has_one = authority)]
    pub team: Account<'info, Team>,

    /// CHECK: Vault PDA holds SOL and stores no data; address is verified by PDA seeds + bump.
    #[account(
        mut,
        seeds = [b"vault", team.key().as_ref()],
        bump = team.vault_bump
    )]
    pub vault: UncheckedAccount<'info>,

    /// Recipient can be any system account (wallet).
    #[account(mut)]
    pub recipient: SystemAccount<'info>,

    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[account]
pub struct Team {
    pub authority: Pubkey,
    pub team_id: u64,
    pub vault_bump: u8,
}

impl Team {
    pub const INIT_SPACE: usize = 32 + 8 + 1; // Pubkey + u64 + u8
}

#[error_code]
pub enum EscrowError {
    #[msg("Deposit amount must be greater than 0.")]
    InvalidAmount,

    #[msg("Vault does not have enough SOL.")]
    InsufficientVaultFunds,
}
