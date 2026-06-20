use anchor_lang::prelude::*;
use crate::state::{AgentRegistry, Role};

/// Constraint helper — use in `#[account(constraint = check_role(&account, Role::Admin)?)]`.
pub fn check_role(registry: &AgentRegistry, required: Role) -> Result<()> {
    require!(registry.role == required, SecurityError::UnauthorizedRole);
    Ok(())
}

#[error_code]
pub enum SecurityError {
    #[msg("Caller does not hold the required role")]
    UnauthorizedRole,
}

pub fn register_agent_handler(_ctx: Context<crate::RegisterAgent>, _role: Role) -> Result<()> {
    Ok(())
}
