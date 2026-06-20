use anchor_lang::prelude::*;

#[error_code]
pub enum BondingCurveError {
    #[msg("Invalid trade amount")]
    InvalidAmount,
    #[msg("Insufficient liquidity")]
    InsufficientLiquidity,
    #[msg("Unauthorized caller")]
    Unauthorized,
}
