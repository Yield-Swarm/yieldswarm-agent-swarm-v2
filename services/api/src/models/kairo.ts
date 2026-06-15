/**
 * Kairo driver cryptographic identity models.
 * IoTeX + EVM compatible addresses derived from secp256k1 keypairs.
 */

export interface DriverIdentity {
  driverId: string;
  deviceId: string;
  iotexAddress: string;
  evmAddress: string;
  publicKey: string;
  createdAt: string;
  platform: 'ios' | 'android' | 'web';
  status: 'active' | 'suspended' | 'pending';
}

export interface SignedTelemetry {
  id: string;
  driverId: string;
  timestamp: string;
  payload: TelemetryPayload;
  signature: string;
  signerAddress: string;
  verified: boolean;
}

export interface TelemetryPayload {
  latitude: number;
  longitude: number;
  speedMph: number;
  heading: number;
  tripId?: string;
  sensorHash: string;
  shardId: number;
}

export interface DriverContribution {
  driverId: string;
  totalSignedRecords: number;
  verifiedRecords: number;
  shardContributions: Record<number, number>;
  estimatedRewardsUsd: number;
  estimatedDepinRewards: number;
  lastContributionAt: string;
}

export interface RegisterDriverRequest {
  deviceId: string;
  platform: DriverIdentity['platform'];
  publicKey?: string;
}

export interface RegisterDriverResponse {
  driverId: string;
  iotexAddress: string;
  evmAddress: string;
  publicKey: string;
  signingInstructions: string;
}
