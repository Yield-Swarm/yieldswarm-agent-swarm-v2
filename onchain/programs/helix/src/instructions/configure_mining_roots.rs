use anchor_lang::prelude::*;
use crate::mining_roots::MINING_ROOT_COUNT;
use crate::state::MiningRootConfig;

#[derive(Accounts)]
pub struct ConfigureMiningRoots<'info> {
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + MiningRootConfig::LEN,
        seeds = [b"mining_roots"],
        bump
    )]
    pub config: Account<'info, MiningRootConfig>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<ConfigureMiningRoots>,
    iotex_treasury: [u8; 20],
    btc_bridge_hash: [u8; 32],
    root_hashes: [[u8; 32]; 10],
) -> Result<()> {
    let cfg = &mut ctx.accounts.config;
    cfg.authority = ctx.accounts.authority.key();
    cfg.iotex_treasury = iotex_treasury;
    cfg.btc_bridge_hash = btc_bridge_hash;
    cfg.root_hashes = root_hashes;
    cfg.bump = ctx.bumps.config;
    Ok(())
}
