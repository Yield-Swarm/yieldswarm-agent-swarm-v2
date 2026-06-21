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

export const HELIX_CHAIN_ID = 14n;

export const EVENT_KIND_HARVEST_TRIGGER = 1;
export const EVENT_KIND_YIELD_RECEIVED = 2;

/** Lamports per signature base fee (approximate). */
export const BASE_TX_FEE_LAMPORTS = 5_000;

/** Priority fee estimate for cross-chain harvest (micro-lamports per CU). */
export const DEFAULT_PRIORITY_FEE_MICROLAMPORTS = 10_000;

export const BRIDGE_GAS_ESTIMATE_LAMPORTS = 25_000;
