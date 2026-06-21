use anchor_lang::prelude::*;

#[error_code]
pub enum CrossChainError {
    #[msg("Unauthorized bridge authority")]
    UnauthorizedBridge,
    #[msg("Unauthorized treasury admin")]
    UnauthorizedTreasuryAdmin,
    #[msg("Replay: nonce already consumed")]
    NonceReplay,
    #[msg("Bridged amount must be positive")]
    ZeroAmount,
    #[msg("Harvest amount exceeds agent daily allowance")]
    AllowanceExceeded,
    #[msg("Invalid agent signature")]
    InvalidAgentSignature,
    #[msg("Treasury vault mismatch")]
    TreasuryMismatch,
    #[msg("Cross-chain inflows are paused")]
    InflowsPaused,
    #[msg("Shard sweeps are paused")]
    SweepsPaused,
    #[msg("Invalid mining root kind")]
    InvalidMiningRoot,
    #[msg("Mining root is inactive")]
    MiningRootInactive,
    #[msg("Invalid route destination")]
    InvalidRouteDestination,
    #[msg("Recipient token account owner mismatch")]
    RecipientOwnerMismatch,
    #[msg("Unknown mining root kind")]
    UnknownRootKind,
}
