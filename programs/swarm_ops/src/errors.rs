use anchor_lang::prelude::*;

#[error_code]
pub enum SwarmOpsError {
    #[msg("Agent ID out of range (max 521)")]
    InvalidAgentId,
    #[msg("Daily spend limit exceeded")]
    DailyLimitExceeded,
    #[msg("Execution boundary violated")]
    BoundaryExceeded,
    #[msg("Proposal not found")]
    ProposalNotFound,
    #[msg("Already approved by this agent")]
    DuplicateApproval,
    #[msg("Consensus threshold not met")]
    ThresholdNotMet,
    #[msg("Proposal already executed")]
    ProposalExecuted,
}
