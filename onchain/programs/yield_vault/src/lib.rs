use anchor_lang::prelude::*;

pub mod errors;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("YVau11111111111111111111111111111111111111");

#[program]
pub mod yield_vault {
    use super::*;

    pub fn initialize_vault(
        ctx: Context<InitializeVault>,
        rebalance_bps: [u16; 5],
    ) -> Result<()> {
        instructions::initialize_vault::handler(ctx, rebalance_bps)
    }

    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        instructions::deposit::handler(ctx, amount)
    }

    pub fn withdraw(ctx: Context<Withdraw>, shares: u64) -> Result<()> {
        instructions::withdraw::handler(ctx, shares)
    }

    pub fn rebalance_and_harvest(ctx: Context<RebalanceAndHarvest>) -> Result<()> {
        instructions::rebalance_and_harvest::handler(ctx)
    }
}
