use anchor_lang::prelude::*;

use crate::state::{
    CHAIN_EVM, CHAIN_SOLANA, CHAIN_SUBSTRATE, CHAIN_ZEC, MiningRoot, ROOT_KIND_BASE_BTC,
    ROOT_KIND_BASE_CBETH, ROOT_KIND_BASE_ETC, ROOT_KIND_BASE_HYPE, ROOT_KIND_PRL, ROOT_KIND_TAO,
    ROOT_KIND_ZEC, DEFAULT_NEXUS_TREASURY,
};

/// Static bootstrap table for the seven Mining Roots supplied by Nexus Chain ops.
pub struct RootBootstrap {
    pub kind: u8,
    pub chain_family: u8,
    pub address: &'static [u8],
    pub solana_recipient: Pubkey,
}

pub fn bootstrap_roots() -> [RootBootstrap; 7] {
    [
        RootBootstrap {
            kind: ROOT_KIND_BASE_ETC,
            chain_family: CHAIN_EVM,
            address: b"0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00",
            solana_recipient: Pubkey::default(),
        },
        RootBootstrap {
            kind: ROOT_KIND_ZEC,
            chain_family: CHAIN_ZEC,
            address: b"t1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY",
            solana_recipient: Pubkey::default(),
        },
        RootBootstrap {
            kind: ROOT_KIND_PRL,
            chain_family: CHAIN_SOLANA,
            address: b"29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9",
            solana_recipient: pubkey!("29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9"),
        },
        RootBootstrap {
            kind: ROOT_KIND_TAO,
            chain_family: CHAIN_SUBSTRATE,
            address: b"5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF",
            solana_recipient: Pubkey::default(),
        },
        RootBootstrap {
            kind: ROOT_KIND_BASE_HYPE,
            chain_family: CHAIN_EVM,
            address: b"0x856e90EDd6d167355FcB6c35a8A857FFCA011Aa0",
            solana_recipient: Pubkey::default(),
        },
        RootBootstrap {
            kind: ROOT_KIND_BASE_CBETH,
            chain_family: CHAIN_EVM,
            address: b"0x455156dFDc95084A8e84e8d734a036A9a2e11Af0",
            solana_recipient: Pubkey::default(),
        },
        RootBootstrap {
            kind: ROOT_KIND_BASE_BTC,
            chain_family: CHAIN_EVM,
            address: b"0x1353f846DB707F6739591d294c80740607F1A87a",
            solana_recipient: Pubkey::default(),
        },
    ]
}

pub fn nexus_treasury_default() -> Pubkey {
    DEFAULT_NEXUS_TREASURY
}

pub fn write_root_entry(root: &mut MiningRoot, registry: Pubkey, bootstrap: &RootBootstrap, bump: u8) {
    root.registry = registry;
    root.root_kind = bootstrap.kind;
    root.chain_family = bootstrap.chain_family;
    root.address_len = bootstrap.address.len().min(64) as u8;
    root.address = [0u8; 64];
    root.address[..bootstrap.address.len().min(64)]
        .copy_from_slice(&bootstrap.address[..bootstrap.address.len().min(64)]);
    root.solana_recipient = bootstrap.solana_recipient;
    root.total_routed = 0;
    root.active = true;
    root.bump = bump;
}

pub fn root_kind_name(kind: u8) -> &'static str {
    match kind {
        ROOT_KIND_BASE_ETC => "base_etc",
        ROOT_KIND_ZEC => "zec",
        ROOT_KIND_PRL => "prl",
        ROOT_KIND_TAO => "tao",
        ROOT_KIND_BASE_HYPE => "base_hype",
        ROOT_KIND_BASE_CBETH => "base_cbeth",
        ROOT_KIND_BASE_BTC => "base_btc",
        _ => "unknown",
    }
}
