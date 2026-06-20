use anchor_lang::prelude::*;

#[derive(Accounts)]
pub struct ApproveStrategy<'info> {
    pub approver: Signer<'info>,
    /// CHECK: proposal PDA stub
    pub proposal: UncheckedAccount<'info>,
}

pub fn handler(_ctx: Context<ApproveStrategy>) -> Result<()> {
    Ok(())
}
