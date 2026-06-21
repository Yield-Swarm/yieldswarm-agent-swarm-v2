import { PublicKey } from '@solana/web3.js';

export const CROSS_CHAIN_PROGRAM_ID = new PublicKey(
  'CrossChn1111111111111111111111111111111111'
);

export const SWARM_OPS_PROGRAM_ID = new PublicKey(
  'SwarmOps111111111111111111111111111111111'
);

export const SHARD_COORDINATOR_PROGRAM_ID = new PublicKey(
  'ShardCrd111111111111111111111111111111111'
);

/** Nexus Treasury — primary Solana profit sink (Solenoid 1). */
export const NEXUS_TREASURY_SOLANA = new PublicKey(
  'kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN'
);

export const HELIX_CHAIN_ID = 14n;

export const EVENT_KIND_HARVEST_TRIGGER = 1;
export const EVENT_KIND_YIELD_RECEIVED = 2;
export const EVENT_KIND_TREASURY_ROUTE = 3;
export const EVENT_KIND_SWEEP = 4;
export const EVENT_KIND_PAUSE = 5;

export const DEST_NEXUS_TREASURY = 0;
export const DEST_MINING_ROOT = 1;

export const SWEEP_INTERNAL_SOLANA = 0;
export const SWEEP_EXTERNAL_MINING = 1;

export const CHAIN_SOLANA = 0;
export const CHAIN_EVM = 1;
export const CHAIN_ZEC = 2;
export const CHAIN_SUBSTRATE = 3;

export const ROOT_KIND_BASE_ETC = 0;
export const ROOT_KIND_ZEC = 1;
export const ROOT_KIND_PRL = 2;
export const ROOT_KIND_TAO = 3;
export const ROOT_KIND_BASE_HYPE = 4;
export const ROOT_KIND_BASE_CBETH = 5;
export const ROOT_KIND_BASE_BTC = 6;

/** Mining Roots — DePIN / external reward sinks (exact addresses from Nexus ops). */
export const MINING_ROOTS = {
  baseEtc: {
    kind: ROOT_KIND_BASE_ETC,
    chainFamily: CHAIN_EVM,
    label: 'Base ETC',
    address: '0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00',
  },
  zec: {
    kind: ROOT_KIND_ZEC,
    chainFamily: CHAIN_ZEC,
    label: 'ZEC',
    address: 't1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY',
  },
  prl: {
    kind: ROOT_KIND_PRL,
    chainFamily: CHAIN_SOLANA,
    label: 'PRL',
    address: '29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9',
    solana: new PublicKey('29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9'),
  },
  tao: {
    kind: ROOT_KIND_TAO,
    chainFamily: CHAIN_SUBSTRATE,
    label: 'TAO',
    address: '5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF',
  },
  baseHype: {
    kind: ROOT_KIND_BASE_HYPE,
    chainFamily: CHAIN_EVM,
    label: 'Base HYPE',
    address: '0x856e90EDd6d167355FcB6c35a8A857FFCA011Aa0',
  },
  baseCbEth: {
    kind: ROOT_KIND_BASE_CBETH,
    chainFamily: CHAIN_EVM,
    label: 'Base cbETH',
    address: '0x455156dFDc95084A8e84e8d734a036A9a2e11Af0',
  },
  baseBtc: {
    kind: ROOT_KIND_BASE_BTC,
    chainFamily: CHAIN_EVM,
    label: 'Base BTC',
    address: '0x1353f846DB707F6739591d294c80740607F1A87a',
  },
} as const;

export const MINING_ROOT_LIST = Object.values(MINING_ROOTS);

/** Lamports per signature base fee (approximate). */
export const BASE_TX_FEE_LAMPORTS = 5_000;

/** Priority fee estimate for cross-chain harvest (micro-lamports per CU). */
export const DEFAULT_PRIORITY_FEE_MICROLAMPORTS = 10_000;

export const BRIDGE_GAS_ESTIMATE_LAMPORTS = 25_000;

export function rootKindLabel(kind: number): string {
  const entry = MINING_ROOT_LIST.find((r) => r.kind === kind);
  return entry?.label ?? `root_${kind}`;
}

export function resolveSweepDestination(
  routeDestination: number,
  miningRootKind: number
): { type: 'nexus' | 'mining'; label: string; address: string } {
  if (routeDestination === DEST_NEXUS_TREASURY) {
    return {
      type: 'nexus',
      label: 'Nexus Treasury',
      address: NEXUS_TREASURY_SOLANA.toBase58(),
    };
  }
  const root = MINING_ROOT_LIST.find((r) => r.kind === miningRootKind);
  return {
    type: 'mining',
    label: root?.label ?? `Mining Root ${miningRootKind}`,
    address: root?.address ?? '',
  };
}
