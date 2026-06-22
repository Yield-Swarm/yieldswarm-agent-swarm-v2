use anchor_lang::prelude::*;
use crate::chains::{YIELD_DEST_BTC_IOPAY, YIELD_DEST_IOTEX, YIELD_DEST_NEXUS};
use crate::errors::CrossChainError;
use crate::state::TreasuryRoutingConfig;

#[derive(Accounts)]
pub struct ConfigureTreasuryRouting<'info> {
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + TreasuryRoutingConfig::LEN,
        seeds = [b"treasury_routing"],
        bump
    )]
    pub routing_config: Account<'info, TreasuryRoutingConfig>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<ConfigureTreasuryRouting>,
    iotex_treasury: [u8; 20],
    btc_bridge_hash: [u8; 32],
    default_destination: u8,
) -> Result<()> {
    require!(
        default_destination <= YIELD_DEST_BTC_IOPAY,
        CrossChainError::InvalidDestination
    );
    let cfg = &mut ctx.accounts.routing_config;
    cfg.authority = ctx.accounts.authority.key();
    cfg.iotex_treasury = iotex_treasury;
    cfg.btc_bridge_hash = btc_bridge_hash;
    cfg.default_destination = default_destination.max(YIELD_DEST_NEXUS);
    cfg.iotex_total_routed = 0;
    cfg.btc_bridge_total_routed = 0;
    cfg.bump = ctx.bumps.routing_config;
    Ok(())
}
