use anchor_lang::prelude::*;

#[error_code]
pub enum ShardCoordinatorError {
    #[msg("Shard id exceeds configured maximum")]
    ShardIdOutOfRange,
    #[msg("Shard vault is inactive")]
    ShardInactive,
    #[msg("Insufficient shard liquidity for rebalance")]
    InsufficientLiquidity,
    #[msg("Rebalance would violate minimum reserve")]
    BelowMinReserve,
    #[msg("Arithmetic overflow")]
    Overflow,
    #[msg("Unauthorized coordinator action")]
    Unauthorized,
    #[msg("Zero amount transfer")]
    ZeroAmount,
}
