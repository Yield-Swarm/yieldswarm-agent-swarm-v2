use anchor_lang::prelude::*;

#[error_code]
pub enum ArenaError {
    #[msg("Unauthorized")]
    Unauthorized,
    #[msg("Arena is paused")]
    ArenaPaused,
    #[msg("Competitor already registered")]
    AlreadyRegistered,
    #[msg("Competitor not found")]
    CompetitorNotFound,
    #[msg("Batch too large (max 64)")]
    BatchTooLarge,
    #[msg("Invalid ZK batch root")]
    InvalidBatchRoot,
    #[msg("Math overflow")]
    MathOverflow,
    #[msg("Insufficient reward pool")]
    InsufficientPool,
}
