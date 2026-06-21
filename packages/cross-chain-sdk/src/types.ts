export interface CrossChainConfigAccount {
  authority: string;
  bridgeAuthority: string;
  treasury: string;
  helixChainId: bigint;
  totalHarvested: bigint;
  totalReceived: bigint;
  lastNonce: bigint;
}

export interface TreasuryRegistryAccount {
  authority: string;
  nexusAuthority: string;
  nexusTreasury: string;
  pausedSweeps: boolean;
  pausedInflows: boolean;
  totalToNexus: bigint;
  totalToMining: bigint;
  miningRootCount: number;
}

export interface MiningRootAccount {
  registry: string;
  rootKind: number;
  chainFamily: number;
  address: string;
  solanaRecipient: string;
  totalRouted: bigint;
  active: boolean;
}

export interface TreasuryVaultAccount {
  config: string;
  mint: string;
  balance: bigint;
}

export interface EventLogPayload {
  kind: number;
  originChainId: bigint;
  assetAmount: bigint;
  agent: string;
  targetVault: string;
  bridgeMessageHash: string;
  timestamp: number;
}

export interface TreasuryRouteEventPayload {
  routeDestination: number;
  miningRootKind: number;
  originChainId: bigint;
  assetAmount: bigint;
  solanaRecipient: string;
  externalAddress: string;
  bridgeMessageHash: string;
  timestamp: number;
}

export interface BridgeTxStatus {
  signature: string;
  confirmed: boolean;
  slot: number | null;
  err: string | null;
}

export interface GasEstimate {
  baseFeeLamports: number;
  priorityFeeLamports: number;
  bridgeGasLamports: number;
  totalLamports: number;
}

export interface YieldRoute {
  protocol: 'kamino' | 'drift' | 'jito';
  label: string;
  apyBps: number;
  tvlUsd: number;
}

export interface YieldVaultState {
  apyBps: number;
  userDeposits: bigint;
  pendingReferralRewards: bigint;
  totalReceived: bigint;
  loading: boolean;
  error: string | null;
}

export interface TreasuryBalancesState {
  nexusTreasury: string;
  totalToNexus: bigint;
  totalToMining: bigint;
  pausedSweeps: boolean;
  pausedInflows: boolean;
  miningRoots: MiningRootAccount[];
  loading: boolean;
  error: string | null;
}
