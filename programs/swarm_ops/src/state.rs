use anchor_lang::prelude::*;

use crate::errors::SwarmOpsError;

/// Global swarm_ops configuration.
#[account]
#[derive(InitSpace)]
pub struct SwarmConfig {
    pub authority: Pubkey,
    pub cross_chain_program: Pubkey,
    pub bump: u8,
}

impl SwarmConfig {
    pub const SEED: &'static [u8] = b"swarm_config";
}

/// Per-agent registry for the 521-agent swarm.
#[account]
#[derive(InitSpace)]
pub struct AgentRegistry {
    pub authority: Pubkey,
    pub agent: Pubkey,
    pub daily_harvest_limit: u64,
    pub daily_harvest_used: u64,
    pub permissions: u8,
    pub last_reset_day: i64,
    pub total_harvests: u64,
    pub bump: u8,
}

impl AgentRegistry {
    pub const SEED: &'static [u8] = b"agent";

    pub fn reset_day_if_needed(&mut self) -> Result<()> {
        let today = Clock::get()?.unix_timestamp / 86_400;
        if today > self.last_reset_day {
            self.daily_harvest_used = 0;
            self.last_reset_day = today;
        }
        Ok(())
    }

    pub fn assert_can_harvest(&self, amount: u64) -> Result<()> {
        require!(
            self.permissions & super::PERM_HARVEST != 0,
            SwarmOpsError::HarvestNotPermitted
        );
        let new_used = self
            .daily_harvest_used
            .checked_add(amount)
            .ok_or(SwarmOpsError::MathOverflow)?;
        require!(
            new_used <= self.daily_harvest_limit,
            SwarmOpsError::DailyLimitExceeded
        );
        Ok(())
    }
}
