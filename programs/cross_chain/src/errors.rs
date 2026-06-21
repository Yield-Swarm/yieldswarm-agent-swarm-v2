use anchor_lang::prelude::*;

#[error_code]
pub enum CrossChainError {
    #[msg("Unauthorized bridge authority")]
    UnauthorizedBridge,
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
}
