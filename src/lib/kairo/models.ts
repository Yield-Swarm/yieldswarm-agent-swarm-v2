/** Kairo driver identity and telemetry data models. */

export interface DriverIdentity {
  id: string;
  /** secp256k1-derived EVM address (0x…) */
  evmAddress: string;
  /** IoTeX bech32 address (io…) */
  iotexAddress: string;
  /** Public key hex (uncompressed secp256k1, 04…) */
  publicKey: string;
  createdAt: string;
  /** Encrypted at rest in production; dev stores a fingerprint only */
  keyFingerprint: string;
  metadata?: Record<string, unknown>;
}

export interface SignedTelemetry {
  id: string;
  driverId: string;
  payload: TelemetryPayload;
  signature: string;
  /** EVM signature format: 0x + r + s + v */
  signerAddress: string;
  receivedAt: string;
  verified: boolean;
  /** Mandelbrot shard this record was routed to */
  mandelbrotShard?: number;
  treeOfLifeNode?: string;
}

export interface TelemetryPayload {
  timestamp: string;
  latitude: number;
  longitude: number;
  speedMph: number;
  headingDeg: number;
  /** Odometer delta since last sample (miles) */
  distanceMiles: number;
  /** Optional vehicle / session metadata */
  sessionId?: string;
  deviceId?: string;
}

export interface ContributionRecord {
  id: string;
  driverId: string;
  telemetryCount: number;
  totalDistanceMiles: number;
  /** Estimated DePIN / crypto reward units (off-chain estimate) */
  estimatedDepinRewards: string;
  /** App revenue share from completed trips */
  appRevenueShare: string;
  currency: string;
  periodStart: string;
  periodEnd: string;
  updatedAt: string;
}

export interface KairoTrip {
  id: string;
  customerId: string;
  driverId: string;
  fareAmount: string;
  currency: string;
  /** 1% flat customer platform fee */
  customerFee: string;
  /** Driver receives 2× base pay component */
  driverPay: string;
  /** Driver instant-cashout fee (if applicable) */
  cashoutFee?: string;
  status: "pending" | "active" | "completed" | "cancelled";
  metadata?: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface DriverEarnings {
  driverId: string;
  currency: string;
  appRevenue: string;
  depinRewards: string;
  tripPay: string;
  total: string;
  pendingCashout: string;
  availableCashout: string;
  breakdown: {
    label: string;
    amount: string;
    source: "app" | "depin" | "trip";
  }[];
}

export interface KairoDB {
  drivers: Record<string, DriverIdentity>;
  telemetry: Record<string, SignedTelemetry>;
  contributions: Record<string, ContributionRecord>;
  trips: Record<string, KairoTrip>;
}

export function emptyKairoDB(): KairoDB {
  return { drivers: {}, telemetry: {}, contributions: {}, trips: {} };
}
