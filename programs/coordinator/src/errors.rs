use anchor_lang::prelude::*;

#[error_code]
pub enum CoordinatorError {
    #[msg("Unauthorized coordinator authority")]
    Unauthorized,
    #[msg("Coordinator operations are globally paused")]
    GloballyPaused,
    #[msg("Bridge operations are paused")]
    BridgePaused,
}
