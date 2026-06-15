/**
 * Kairo domain models — driver identity, signed telemetry, and earnings.
 *
 * Every Kairo driver is a YieldSwarm DePIN node with a persistent
 * cryptographic identity (IoTeX + EVM compatible) and signed telemetry
 * routed into the Mandelbrot / Tree of Life data mesh.
 */

export type DriverStatus = "pending" | "active" | "suspended";

/** Persistent cryptographic identity for a Kairo driver. */
export interface DriverIdentity {
  /** Internal UUID. */
  id: string;
  /** Human-readable display name. */
  displayName: string;
  /** EVM-compatible address (also valid on IoTeX — same secp256k1 derivation). */
  evmAddress: string;
  /** IoTeX native address (io1… prefix, derived from same keypair). */
  iotexAddress: string;
  /** Compressed secp256k1 public key (hex, no 0x prefix). */
  publicKey: string;
  /** BIP44 derivation path used. */
  derivationPath: string;
  status: DriverStatus;
  /** Shard in the 10,080-agent mesh this driver maps to. */
  swarmShardId: number;
  createdAt: string;
  lastActiveAt?: string;
}

/** A single signed telemetry event from a driver's device. */
export interface SignedTelemetryEvent {
  id: string;
  driverId: string;
  /** Event type: location, speed, route_segment, idle, etc. */
  eventType: string;
  /** ISO timestamp from the device. */
  timestamp: string;
  /** Arbitrary telemetry payload (coordinates, speed, battery, etc.). */
  payload: Record<string, unknown>;
  /** ECDSA signature over canonical JSON (hex, 0x-prefixed). */
  signature: string;
  /** Signer's EVM address (must match driver's evmAddress). */
  signerAddress: string;
  /** Mandelbrot shard this event routes to. */
  mandelbrotShard?: number;
  ingestedAt?: string;
}

/** Aggregated data contribution stats for a driver. */
export interface DriverContribution {
  driverId: string;
  totalEvents: number;
  signedEvents: number;
  invalidSignatures: number;
  /** Kilometres driven (from signed location events). */
  totalKm: number;
  /** Mandelbrot shards this driver has contributed to. */
  mandelbrotShards: number[];
  /** Estimated DePIN reward points (pre-settlement). */
  estimatedRewardPoints: number;
  lastEventAt?: string;
}

/** Earnings breakdown: app revenue + DePIN/crypto rewards. */
export interface DriverEarnings {
  driverId: string;
  period: string; // e.g. "2026-06"
  /** Gross ride revenue before fees. */
  grossRideRevenue: string;
  /** Driver take (2× base rate per Kairo model). */
  driverPayout: string;
  currency: string;
  /** 1% customer platform fee collected. */
  platformFeeCollected: string;
  /** DePIN / crypto reward estimate. */
  depinRewards: string;
  depinRewardCurrency: string;
  /** Instant cashout fee if used. */
  instantCashoutFee?: string;
  /** Net to driver after all deductions. */
  netEarnings: string;
  breakdown: EarningsLineItem[];
}

export interface EarningsLineItem {
  label: string;
  amount: string;
  currency: string;
  category: "ride" | "depin" | "fee" | "bonus";
}

/** Customer ride with 1% flat platform fee. */
export interface KairoRide {
  id: string;
  customerId: string;
  driverId: string;
  fare: string;
  currency: string;
  /** 1% flat fee on fare. */
  platformFee: string;
  /** Driver receives 2× base (fare + platform fee absorbed by customer). */
  driverEarnings: string;
  status: "pending" | "active" | "completed" | "cancelled";
  createdAt: string;
  completedAt?: string;
}
