use anchor_lang::prelude::*;
use crate::events::RemoteHarvestTriggered;

#[derive(Accounts)]
pub struct TriggerRemoteHarvest<'info> {
    pub authority: Signer<'info>,
}

pub fn handler(ctx: Context<TriggerRemoteHarvest>) -> Result<()> {
    emit!(RemoteHarvestTriggered {
        authority: ctx.accounts.authority.key(),
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}
