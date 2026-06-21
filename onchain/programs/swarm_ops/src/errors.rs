use anchor_lang::prelude::*;

#[error_code]
pub enum SwarmOpsError {
    #[msg("Shard id exceeds MAX_AGENTS")]
    ShardOverflow,
    #[msg("Daily spend limit exceeded")]
    SpendLimitExceeded,
    #[msg("Proposal already executed")]
    AlreadyExecuted,
}
