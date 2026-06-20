use anchor_lang::prelude::*;

#[derive(Accounts)]
#[instruction(proposal_id: u64)]
pub struct ProposeStrategy<'info> {
    pub proposer: Signer<'info>,
    /// CHECK: proposal PDA stub — seeds = ["proposal", proposal_id]
    #[account(seeds = [b"proposal", proposal_id.to_le_bytes().as_ref()], bump)]
    pub proposal: UncheckedAccount<'info>,
}

pub fn handler(_ctx: Context<ProposeStrategy>, _proposal_id: u64) -> Result<()> {
    Ok(())
}
