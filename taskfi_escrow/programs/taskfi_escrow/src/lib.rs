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
    pub fn create_task(ctx: Context<CreateTask>, task_id: u64, reward_lamports: u64) -> Result<()> {
        require!(reward_lamports > 0, EscrowError::InvalidAmount);
    
        let task = &mut ctx.accounts.task;
        task.team = ctx.accounts.team.key();
        task.task_id = task_id;
        task.creator = ctx.accounts.authority.key();
        task.assignee = Pubkey::default();
        task.reward_lamports = reward_lamports;
        task.status = TaskStatus::Open as u8;
    
        Ok(())
    }
    
    pub fn assign_task(ctx: Context<AssignTask>) -> Result<()> {
        let task = &mut ctx.accounts.task;
        require!(task.status == TaskStatus::Open as u8, EscrowError::InvalidTaskState);
    
        task.assignee = ctx.accounts.assignee.key();
        task.status = TaskStatus::Assigned as u8;
        Ok(())
    }
    
    pub fn mark_complete(ctx: Context<MarkComplete>) -> Result<()> {
        let task = &mut ctx.accounts.task;
        require!(task.status == TaskStatus::Assigned as u8, EscrowError::InvalidTaskState);
        require!(task.assignee == ctx.accounts.assignee.key(), EscrowError::NotAssignee);
    
        task.status = TaskStatus::Completed as u8;
        Ok(())
    }
    
    pub fn payout_task(ctx: Context<PayoutTask>) -> Result<()> {
        let task = &mut ctx.accounts.task;
        require!(task.status == TaskStatus::Completed as u8, EscrowError::InvalidTaskState);
        require!(task.assignee != Pubkey::default(), EscrowError::NoAssignee);
    
        let amount = task.reward_lamports;
    
        // Optional: vault solvency check
        let vault_lamports = ctx.accounts.vault.to_account_info().lamports();
        require!(vault_lamports >= amount, EscrowError::InsufficientVaultFunds);
    
        // Sign as vault PDA
        let team_key = ctx.accounts.team.key();
        let seeds: &[&[u8]] = &[b"vault", team_key.as_ref(), &[ctx.accounts.team.vault_bump]];
        let signer_seeds: &[&[&[u8]]] = &[seeds];
    
        let ix = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.vault.key(),
            &ctx.accounts.recipient.key(),
            amount,
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
    
        task.status = TaskStatus::Paid as u8;
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

#[derive(Accounts)]
#[instruction(task_id: u64)]
pub struct CreateTask<'info> {
    #[account(has_one = authority)]
    pub team: Account<'info, Team>,

    #[account(
        init,
        payer = authority,
        space = 8 + Task::INIT_SPACE,
        seeds = [b"task", team.key().as_ref(), &task_id.to_le_bytes()],
        bump
    )]
    pub task: Account<'info, Task>,

    #[account(mut)]
    pub authority: Signer<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AssignTask<'info> {
    #[account(has_one = authority)]
    pub team: Account<'info, Team>,

    #[account(
        mut,
        constraint = task.team == team.key() @ EscrowError::TaskTeamMismatch
    )]
    pub task: Account<'info, Task>,

    /// Who will do the task
    pub assignee: SystemAccount<'info>,

    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct MarkComplete<'info> {
    pub team: Account<'info, Team>,

    #[account(
        mut,
        constraint = task.team == team.key() @ EscrowError::TaskTeamMismatch
    )]
    pub task: Account<'info, Task>,

    pub assignee: Signer<'info>,
}

#[derive(Accounts)]
pub struct PayoutTask<'info> {
    #[account(has_one = authority)]
    pub team: Account<'info, Team>,

    #[account(
        mut,
        constraint = task.team == team.key() @ EscrowError::TaskTeamMismatch
    )]
    pub task: Account<'info, Task>,

    /// CHECK: Vault PDA holds SOL and stores no data; verified by seeds + bump.
    #[account(
        mut,
        seeds = [b"vault", team.key().as_ref()],
        bump = team.vault_bump
    )]
    pub vault: UncheckedAccount<'info>,

    /// Recipient must be the current assignee
    #[account(
        mut,
        constraint = recipient.key() == task.assignee @ EscrowError::RecipientNotAssignee
    )]
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

    #[msg("Task is not in the expected state for this action.")]
    InvalidTaskState,

    #[msg("Only the assignee can mark this task complete.")]
    NotAssignee,

    #[msg("Task has no assignee.")]
    NoAssignee,

    #[msg("Task does not belong to this team.")]
    TaskTeamMismatch,

    #[msg("Recipient must be the task assignee.")]
    RecipientNotAssignee,
}

#[repr(u8)]
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum TaskStatus {
    Open = 0,
    Assigned = 1,
    Completed = 2,
    Paid = 3,
}

#[account]
pub struct Task {
    pub team: Pubkey,
    pub task_id: u64,
    pub creator: Pubkey,
    pub assignee: Pubkey,       // Pubkey::default() when unassigned
    pub reward_lamports: u64,
    pub status: u8,             // stores TaskStatus as u8
}

impl Task {
    pub const INIT_SPACE: usize =
        32 + // team
        8  + // task_id
        32 + // creator
        32 + // assignee
        8  + // reward_lamports
        1;   // status
}