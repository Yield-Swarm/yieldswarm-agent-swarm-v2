use anchor_lang::prelude::*;

#[error_code]
pub enum CrossChainError {
    #[msg("Unauthorized relayer")]
    UnauthorizedRelayer,
    #[msg("Invalid yield destination")]
    InvalidDestination,
    #[msg("Amount must be greater than zero")]
    ZeroAmount,
}
