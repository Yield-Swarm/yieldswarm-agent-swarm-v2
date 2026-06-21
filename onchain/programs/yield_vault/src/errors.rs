use anchor_lang::prelude::*;

#[error_code]
pub enum VaultError {
    #[msg("Rebalance weights must sum to 10000 bps")]
    InvalidRebalanceSplit,
    #[msg("Slippage tolerance exceeded")]
    SlippageExceeded,
    #[msg("Unauthorized harvest caller")]
    UnauthorizedHarvest,
    #[msg("Math overflow")]
    MathOverflow,
}
