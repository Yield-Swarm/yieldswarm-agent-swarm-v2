use anchor_lang::prelude::*;
use crate::events::CrossChainYieldReceived;

#[derive(Accounts)]
pub struct ReceiveCrossChainYield<'info> {
    pub relayer: Signer<'info>,
}

pub fn handler(_ctx: Context<ReceiveCrossChainYield>, amount: u64) -> Result<()> {
    emit!(CrossChainYieldReceived {
        amount,
        source_chain_id: 0,
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}
