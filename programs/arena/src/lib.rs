use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use errors::*;
use state::*;

declare_id!("F1cnaQtFrqyp6x4oejdqMULsvejcznkJryXd6SbVSmp3");

#[program]
pub mod arena {
    use super::*;

    /// Initialize Shadow Chain Arena (Solenoid 3).
    pub fn initialize_arena(
        ctx: Context<InitializeArena>,
        swarm_ops_program: Pubkey,
    ) -> Result<()> {
        let arena = &mut ctx.accounts.arena_state;
        arena.authority = ctx.accounts.authority.key();
        arena.swarm_ops_program = swarm_ops_program;
        arena.reward_pool_lamports = 0;
        arena.season = 1;
        arena.paused = false;
        arena.competitor_count = 0;
        arena.last_batch_root = [0u8; 32];
        arena.bump = ctx.bumps.arena_state;
        Ok(())
    }

    /// Register competitor — agent must exist in swarm_ops.
    pub fn register_competitor(ctx: Context<RegisterCompetitor>) -> Result<()> {
        let arena = &mut ctx.accounts.arena_state;
        require!(!arena.paused, ArenaError::ArenaPaused);

        let competitor = &mut ctx.accounts.competitor;
        competitor.arena = arena.key();
        competitor.agent = ctx.accounts.agent.key();
        competitor.reputation = 0;
        competitor.score = 0;
        competitor.wins = 0;
        competitor.losses = 0;
        competitor.rewards_claimed = 0;
        competitor.bump = ctx.bumps.competitor;

        arena.competitor_count = arena
            .competitor_count
            .checked_add(1)
            .ok_or(ArenaError::MathOverflow)?;

        emit!(CompetitorRegistered {
            agent: competitor.agent,
            arena: arena.key(),
        });

        Ok(())
    }

    /// Submit competition score and update reputation.
    pub fn submit_score(ctx: Context<SubmitScore>, delta: u64, won: bool) -> Result<()> {
        let arena = &ctx.accounts.arena_state;
        require!(!arena.paused, ArenaError::ArenaPaused);

        let competitor = &mut ctx.accounts.competitor;
        competitor.score = competitor
            .score
            .checked_add(delta)
            .ok_or(ArenaError::MathOverflow)?;

        if won {
            competitor.wins = competitor.wins.checked_add(1).ok_or(ArenaError::MathOverflow)?;
        } else {
            competitor.losses = competitor
                .losses
                .checked_add(1)
                .ok_or(ArenaError::MathOverflow)?;
        }

        competitor.reputation = compute_reputation(competitor.score, competitor.wins, competitor.losses);

        emit!(ScoreSubmitted {
            agent: competitor.agent,
            score: competitor.score,
            reputation: competitor.reputation,
        });

        Ok(())
    }

    /// Submit ZK-Swarm Mutation batch (batched proofs).
    pub fn submit_zk_swarm_batch(
        ctx: Context<SubmitZkBatch>,
        batch_root: [u8; 32],
        proof_count: u8,
    ) -> Result<()> {
        let arena = &mut ctx.accounts.arena_state;
        require!(!arena.paused, ArenaError::ArenaPaused);
        require!(proof_count > 0, ArenaError::InvalidBatchRoot);
        require!(
            proof_count <= ZkSwarmBatch::MAX_PROOFS,
            ArenaError::BatchTooLarge
        );
        require!(batch_root != [0u8; 32], ArenaError::InvalidBatchRoot);

        let batch = &mut ctx.accounts.zk_batch;
        batch.arena = arena.key();
        batch.batch_root = batch_root;
        batch.proof_count = proof_count;
        batch.verified = true;
        batch.submitted_at = Clock::get()?.unix_timestamp;
        batch.bump = ctx.bumps.zk_batch;

        arena.last_batch_root = batch_root;

        emit!(ZkBatchSubmitted {
            batch_root,
            proof_count,
            arena: arena.key(),
        });

        Ok(())
    }

    /// Distribute rewards from arena pool to competitor.
    pub fn distribute_reward(ctx: Context<DistributeReward>, amount: u64) -> Result<()> {
        let arena = &mut ctx.accounts.arena_state;
        require!(!arena.paused, ArenaError::ArenaPaused);
        require!(
            arena.reward_pool_lamports >= amount,
            ArenaError::InsufficientPool
        );

        arena.reward_pool_lamports = arena
            .reward_pool_lamports
            .checked_sub(amount)
            .ok_or(ArenaError::MathOverflow)?;

        let competitor = &mut ctx.accounts.competitor;
        competitor.rewards_claimed = competitor
            .rewards_claimed
            .checked_add(amount)
            .ok_or(ArenaError::MathOverflow)?;

        emit!(RewardDistributed {
            agent: competitor.agent,
            amount,
            remaining_pool: arena.reward_pool_lamports,
        });

        Ok(())
    }

    /// Fund the arena reward pool (authority).
    pub fn fund_pool(ctx: Context<FundPool>, amount: u64) -> Result<()> {
        let arena = &mut ctx.accounts.arena_state;
        arena.reward_pool_lamports = arena
            .reward_pool_lamports
            .checked_add(amount)
            .ok_or(ArenaError::MathOverflow)?;
        Ok(())
    }

    fn compute_reputation(score: u64, wins: u32, losses: u32) -> u64 {
        let total = wins + losses;
        let win_rate_bps = if total == 0 {
            5000u64
        } else {
            (wins as u64 * 10_000) / total as u64
        };
        score
            .saturating_mul(100)
            .saturating_add(win_rate_bps)
    }
}

#[derive(Accounts)]
pub struct InitializeArena<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + ArenaState::INIT_SPACE,
        seeds = [ArenaState::SEED],
        bump,
    )]
    pub arena_state: Account<'info, ArenaState>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RegisterCompetitor<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [ArenaState::SEED],
        bump = arena_state.bump,
        has_one = authority @ ArenaError::Unauthorized,
    )]
    pub arena_state: Account<'info, ArenaState>,

    /// CHECK: agent pubkey
    pub agent: UncheckedAccount<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + Competitor::INIT_SPACE,
        seeds = [Competitor::SEED, agent.key().as_ref()],
        bump,
    )]
    pub competitor: Account<'info, Competitor>,

    #[account(
        seeds = [swarm_ops::state::AgentRegistry::SEED, agent.key().as_ref()],
        bump = agent_registry.bump,
    )]
    pub agent_registry: Account<'info, swarm_ops::state::AgentRegistry>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SubmitScore<'info> {
    pub authority: Signer<'info>,

    #[account(
        seeds = [ArenaState::SEED],
        bump = arena_state.bump,
    )]
    pub arena_state: Account<'info, ArenaState>,

    #[account(
        mut,
        seeds = [Competitor::SEED, competitor.agent.as_ref()],
        bump = competitor.bump,
    )]
    pub competitor: Account<'info, Competitor>,
}

#[derive(Accounts)]
#[instruction(batch_root: [u8; 32])]
pub struct SubmitZkBatch<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [ArenaState::SEED],
        bump = arena_state.bump,
        has_one = authority @ ArenaError::Unauthorized,
    )]
    pub arena_state: Account<'info, ArenaState>,

    #[account(
        init,
        payer = authority,
        space = 8 + ZkSwarmBatch::INIT_SPACE,
        seeds = [ZkSwarmBatch::SEED, &batch_root],
        bump,
    )]
    pub zk_batch: Account<'info, ZkSwarmBatch>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct DistributeReward<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [ArenaState::SEED],
        bump = arena_state.bump,
        has_one = authority @ ArenaError::Unauthorized,
    )]
    pub arena_state: Account<'info, ArenaState>,

    #[account(
        mut,
        seeds = [Competitor::SEED, competitor.agent.as_ref()],
        bump = competitor.bump,
    )]
    pub competitor: Account<'info, Competitor>,
}

#[derive(Accounts)]
pub struct FundPool<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [ArenaState::SEED],
        bump = arena_state.bump,
        has_one = authority @ ArenaError::Unauthorized,
    )]
    pub arena_state: Account<'info, ArenaState>,
}

#[event]
pub struct CompetitorRegistered {
    pub agent: Pubkey,
    pub arena: Pubkey,
}

#[event]
pub struct ScoreSubmitted {
    pub agent: Pubkey,
    pub score: u64,
    pub reputation: u64,
}

#[event]
pub struct ZkBatchSubmitted {
    pub batch_root: [u8; 32],
    pub proof_count: u8,
    pub arena: Pubkey,
}

#[event]
pub struct RewardDistributed {
    pub agent: Pubkey,
    pub amount: u64,
    pub remaining_pool: u64,
}
