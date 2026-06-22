use anchor_lang::prelude::*;

#[error_code]
pub enum ArenaError {
    #[msg("Arena competitor capacity reached")]
    ArenaFull,
    #[msg("Competitor not registered")]
    CompetitorMissing,
    #[msg("Reputation below floor after slash")]
    ReputationTooLow,
    #[msg("Invalid slash penalty")]
    InvalidPenalty,
    #[msg("Reward epoch already finalized")]
    EpochFinalized,
    #[msg("Zero reward amount")]
    ZeroReward,
    #[msg("Unauthorized arena authority")]
    Unauthorized,
}
