use anchor_lang::prelude::*;

#[error_code]
pub enum SwarmOpsError {
    #[msg("Unauthorized swarm_ops authority")]
    Unauthorized,
    #[msg("Unauthorized CPI caller program")]
    UnauthorizedCaller,
    #[msg("Agent does not have harvest permission")]
    HarvestNotPermitted,
    #[msg("Daily harvest limit exceeded")]
    DailyLimitExceeded,
    #[msg("Arithmetic overflow")]
    MathOverflow,
}
