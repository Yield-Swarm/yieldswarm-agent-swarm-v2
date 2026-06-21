/** Static treasury manifest — keep in sync with config/TREASURY_MANIFEST.json */
export const TREASURY_MANIFEST_DEFAULT = {
  version: '2.0',
  updated_at: '2026-06-20',
  nexus_treasury: {
    solana: 'kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN',
    description: 'Primary on-chain Nexus Treasury (Solana)',
  },
  mining_roots: {
    base_etc: '0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00',
    zec: 't1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY',
    prl: '29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9',
    tao: '5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF',
    base_hype: '0x856e90EDd6d167355FcB6c35a8A857FFCA011Aa0',
    base_cbeth: '0x455156dFDc95084A8e84e8d734a036A9a2e11Af0',
    base_btc: '0x1353f846DB707F6739591d294c80740607F1A87a',
    iotex: '0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567',
    btc_via_iopay: 'bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8',
  },
  iotex_hub: {
    primary: '0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567',
    btc_bridge: 'bc1qssmlvhth0sm4xslnvf5a7nlv038u3txkc3l0u8',
    description: 'IoTeX ecosystem expansion via IOPAY',
  },
} as const;

/** SHA-256 of iotex_hub.btc_bridge — sync with config/TREASURY_MANIFEST.json */
export const BTC_BRIDGE_HASH_HEX =
  'e715fb5cbc675e1f51b4b349f889b23ba553f58b7df7e2f43bbdd096330ca438';

export type TreasuryManifest = typeof TREASURY_MANIFEST_DEFAULT;
