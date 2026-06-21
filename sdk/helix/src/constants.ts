/**
 * Program IDs — sync with Anchor.toml via `anchor keys sync` after deploy.
 */
export const PROGRAM_IDS = {
  crossChain: '9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt',
  swarmOps: '6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz',
  coordinator: 'DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p',
} as const;

/** PDA seeds (must match on-chain). */
export const SEEDS = {
  treasury: Buffer.from('treasury'),
  bridgeState: Buffer.from('bridge_state'),
  harvest: Buffer.from('harvest'),
  agent: Buffer.from('agent'),
  swarmConfig: Buffer.from('swarm_config'),
  coordinator: Buffer.from('coordinator'),
} as const;

/** Known Helix routing chain ids. */
export const CHAIN_IDS = {
  HELIX: 1,
  SOLANA: 2,
  ETHEREUM: 3,
} as const;

/** Default max slippage — 50 bps (0.5%). */
export const DEFAULT_MAX_SLIPPAGE_BPS = 50;

/** Event kind constants (mirror on-chain). */
export const EVENT_KIND = {
  HARVEST: 1,
  RECEIVE: 2,
  PAUSE: 3,
} as const;

export type HarvestStatus = 'pending' | 'bridging' | 'completed' | 'failed' | 'cancelled';

export const HARVEST_STATUS: Record<number, HarvestStatus> = {
  0: 'pending',
  1: 'bridging',
  2: 'completed',
  3: 'failed',
  4: 'cancelled',
};

export interface BridgeConfig {
  bridgeAuthority: string;
  minHarvestAmount: bigint;
  maxSlippageBps: number;
  bridgeFeeLamports: bigint;
  paused: boolean;
}

export interface HarvestParams {
  originChainId: number;
  targetChainId: number;
  amount: bigint;
  maxSlippageBps?: number;
}

export interface GasEstimate {
  baseFeeLamports: bigint;
  bridgeFeeLamports: bigint;
  rentLamports: bigint;
  totalLamports: bigint;
}

export interface BridgeEventLog {
  kind: number;
  originChainId: number;
  agent: string;
  amount: bigint;
  status: number;
  message: Uint8Array;
  signature: string;
}
