use anchor_lang::prelude::*;
use crate::events::{EventLog, EVENT_KIND_HARVEST_TRIGGER, RemoteHarvestTriggered};
use crate::state::BridgeState;

#[derive(Accounts)]
pub struct TriggerRemoteHarvest<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"bridge_state"],
        bump = bridge_state.bump
    )]
    pub bridge_state: Account<'info, BridgeState>,
}

pub fn handler(ctx: Context<TriggerRemoteHarvest>, origin_chain_id: u32) -> Result<()> {
    let clock = Clock::get()?;
    let treasury = ctx.accounts.bridge_state.treasury;
    emit!(RemoteHarvestTriggered {
        authority: ctx.accounts.authority.key(),
        origin_chain_id,
        target_treasury: treasury,
        timestamp: clock.unix_timestamp,
    });
    emit!(EventLog {
        kind: EVENT_KIND_HARVEST_TRIGGER,
        program: crate::ID,
        actor: ctx.accounts.authority.key(),
        amount: 0,
        chain_id: origin_chain_id,
        signature_hash: [0u8; 32],
        timestamp: clock.unix_timestamp,
    });
    ctx.accounts.bridge_state.last_harvest_ts = clock.unix_timestamp;
    Ok(())
}
