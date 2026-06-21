use anchor_lang::prelude::*;

#[error_code]
pub enum CrossChainError {
    #[msg("Unauthorized bridge authority")]
    Unauthorized,
    #[msg("Bridge is paused")]
    BridgePaused,
    #[msg("Coordinator global pause active")]
    CoordinatorPaused,
    #[msg("Invalid bridge signature")]
    InvalidBridgeSignature,
    #[msg("Harvest request not in valid state")]
    InvalidHarvestStatus,
    #[msg("Harvest request mismatch")]
    HarvestMismatch,
    #[msg("Reentrancy guard — operation already in progress")]
    Reentrancy,
    #[msg("Slippage exceeds configured maximum")]
    SlippageExceeded,
    #[msg("Amount below minimum harvest threshold")]
    BelowMinimum,
    #[msg("Arithmetic overflow")]
    MathOverflow,
    #[msg("Invalid origin chain id")]
    InvalidOriginChain,
    #[msg("Agent harvest not authorized")]
    AgentNotAuthorized,
}
