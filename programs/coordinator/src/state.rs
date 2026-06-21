use anchor_lang::prelude::*;

/// Nexus Chain coordinator state (Solenoid 1).
#[account]
#[derive(InitSpace)]
pub struct CoordinatorState {
    pub authority: Pubkey,
    pub bridge_program: Pubkey,
    pub global_paused: bool,
    pub bridge_paused: bool,
    pub version: u8,
    pub bump: u8,
}

impl CoordinatorState {
    pub const SEED: &'static [u8] = b"coordinator";

    pub fn assert_operational(&self) -> Result<()> {
        require!(!self.global_paused, crate::errors::CoordinatorError::GloballyPaused);
        Ok(())
    }

    pub fn assert_bridge_operational(&self) -> Result<()> {
        self.assert_operational()?;
        require!(!self.bridge_paused, crate::errors::CoordinatorError::BridgePaused);
        Ok(())
    }
}
