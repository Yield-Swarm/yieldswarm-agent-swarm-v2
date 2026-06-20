use anchor_lang::prelude::*;

pub mod constraints;
pub mod state;

pub use constraints::*;
pub use state::*;

declare_id!("Secu1111111111111111111111111111111111111");

#[program]
pub mod security {
    use super::*;

    /// Stub entrypoint — RBAC types and `check_role` live in `state` / `constraints`.
    pub fn register_agent(ctx: Context<RegisterAgent>, role: Role) -> Result<()> {
        constraints::register_agent_handler(ctx, role)
    }
}

#[derive(Accounts)]
pub struct RegisterAgent<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    pub agent: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = 8 + AgentRegistry::LEN,
        seeds = [b"security_agent", agent.key().as_ref()],
        bump
    )]
    pub agent_registry: Account<'info, AgentRegistry>,
    pub system_program: Program<'info, System>,
}
