/**
 * YieldSwarm on-chain SDK — program ID registry (Instance B extends bridge + hooks).
 */
import { PublicKey } from '@solana/web3.js';

export const PROGRAM_IDS = {
  yieldVault: new PublicKey('YVau11111111111111111111111111111111111111'),
  bondingCurve: new PublicKey('Bond1111111111111111111111111111111111111'),
  crossChain: new PublicKey('XChn1111111111111111111111111111111111111'),
  swarmOps: new PublicKey('Swrm1111111111111111111111111111111111111'),
  coordinator: new PublicKey('Cord1111111111111111111111111111111111111'),
  security: new PublicKey('Secu1111111111111111111111111111111111111'),
} as const;

export const PDA_SEEDS = {
  vaultState: 'vault_state',
  vaultAuthority: 'vault_authority',
  referralRegistry: 'referral_registry',
  agentRegistry: 'agent_registry',
  shardVault: 'shard_vault',
} as const;

export type ProgramName = keyof typeof PROGRAM_IDS;
