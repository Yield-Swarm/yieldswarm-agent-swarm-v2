use anchor_lang::prelude::*;
use anchor_lang::solana_program::ed25519_program;
use anchor_lang::solana_program::sysvar::instructions::{
    load_instruction_at_checked, ID as INSTRUCTIONS_ID,
};

use crate::errors::CrossChainError;

/// Verify an ed25519 signature over `message` using the Ed25519 native program
/// instruction immediately preceding the current instruction in the transaction.
pub fn verify_ed25519_preinstruction(
    instructions_sysvar: &AccountInfo,
    expected_signer: &Pubkey,
    message: &[u8],
) -> Result<()> {
    require!(
        instructions_sysvar.key() == INSTRUCTIONS_ID,
        CrossChainError::InvalidBridgeSignature
    );

    let current_index = anchor_lang::solana_program::sysvar::instructions::load_current_index_checked(
        instructions_sysvar,
    )
    .map_err(|_| CrossChainError::InvalidBridgeSignature)?;

    require!(current_index > 0, CrossChainError::InvalidBridgeSignature);

    let ed25519_ix = load_instruction_at_checked((current_index - 1) as usize, instructions_sysvar)
        .map_err(|_| CrossChainError::InvalidBridgeSignature)?;

    require!(
        ed25519_ix.program_id == ed25519_program::ID,
        CrossChainError::InvalidBridgeSignature
    );

    // Ed25519 instruction data layout:
    // u8 num_signatures, padding, then per signature:
    // u16 sig_offset, u16 sig_instruction_index,
    // u16 pubkey_offset, u16 pubkey_instruction_index,
    // u16 msg_offset, u16 msg_size, u16 msg_instruction_index
    let data = ed25519_ix.data.as_slice();
    require!(data.len() >= 16, CrossChainError::InvalidBridgeSignature);
    require!(data[0] == 1, CrossChainError::InvalidBridgeSignature);

    let sig_offset = u16::from_le_bytes([data[2], data[3]]) as usize;
    let pubkey_offset = u16::from_le_bytes([data[6], data[7]]) as usize;
    let msg_offset = u16::from_le_bytes([data[10], data[11]]) as usize;
    let msg_size = u16::from_le_bytes([data[12], data[13]]) as usize;

    require!(
        pubkey_offset + 32 <= data.len()
            && sig_offset + 64 <= data.len()
            && msg_offset + msg_size <= data.len(),
        CrossChainError::InvalidBridgeSignature
    );

    let pubkey_bytes: [u8; 32] = data[pubkey_offset..pubkey_offset + 32]
        .try_into()
        .map_err(|_| CrossChainError::InvalidBridgeSignature)?;
    let signer = Pubkey::new_from_array(pubkey_bytes);
    require_keys_eq!(
        signer,
        *expected_signer,
        CrossChainError::InvalidBridgeSignature
    );

    let on_chain_msg = &data[msg_offset..msg_offset + msg_size];
    require!(on_chain_msg == message, CrossChainError::InvalidBridgeSignature);

    Ok(())
}

/// Canonical message bytes for bridge settlement signatures.
pub fn bridge_message_bytes(
    harvest_request: &Pubkey,
    origin_chain_id: u32,
    amount: u64,
    nonce: u64,
) -> Vec<u8> {
    let mut msg = Vec::with_capacity(32 + 4 + 8 + 8);
    msg.extend_from_slice(harvest_request.as_ref());
    msg.extend_from_slice(&origin_chain_id.to_le_bytes());
    msg.extend_from_slice(&amount.to_le_bytes());
    msg.extend_from_slice(&nonce.to_le_bytes());
    msg
}

pub fn message_hash(message: &[u8]) -> [u8; 32] {
    anchor_lang::solana_program::hash::hash(message).to_bytes()
}
