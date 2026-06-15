import { createHash, createSign, createVerify, generateKeyPairSync, randomBytes } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import type {
  DriverIdentity,
  DriverContribution,
  RegisterDriverRequest,
  RegisterDriverResponse,
  SignedTelemetry,
  TelemetryPayload,
} from '../models/kairo.js';

const drivers = new Map<string, DriverIdentity>();
const contributions = new Map<string, DriverContribution>();
const telemetryStore: SignedTelemetry[] = [];

function deriveEvmAddress(publicKeyHex: string): string {
  const hash = createHash('sha256').update(Buffer.from(publicKeyHex, 'hex')).digest();
  return '0x' + hash.subarray(hash.length - 20).toString('hex');
}

function deriveIotexAddress(evmAddress: string): string {
  return 'io' + evmAddress.slice(2, 42);
}

export function registerDriver(req: RegisterDriverRequest): RegisterDriverResponse {
  let publicKey: string;
  let privateKey: string;

  if (req.publicKey) {
    publicKey = req.publicKey;
    privateKey = '';
  } else {
    const pair = generateKeyPairSync('ec', { namedCurve: 'secp256k1' });
    publicKey = pair.publicKey.export({ type: 'spki', format: 'der' }).toString('hex');
    privateKey = pair.privateKey.export({ type: 'pkcs8', format: 'der' }).toString('hex');
  }

  const evmAddress = deriveEvmAddress(publicKey);
  const iotexAddress = deriveIotexAddress(evmAddress);
  const driverId = uuidv4();

  const identity: DriverIdentity = {
    driverId,
    deviceId: req.deviceId,
    iotexAddress,
    evmAddress,
    publicKey,
    createdAt: new Date().toISOString(),
    platform: req.platform,
    status: 'active',
  };

  drivers.set(driverId, identity);
  contributions.set(driverId, {
    driverId,
    totalSignedRecords: 0,
    verifiedRecords: 0,
    shardContributions: {},
    estimatedRewardsUsd: 0,
    estimatedDepinRewards: 0,
    lastContributionAt: new Date().toISOString(),
  });

  return {
    driverId,
    iotexAddress,
    evmAddress,
    publicKey,
    signingInstructions:
      'Sign telemetry JSON with secp256k1 private key. POST to /api/v1/kairo/telemetry with signature header.',
    ...(process.env.NODE_ENV === 'development' && privateKey ? { _devPrivateKey: privateKey } : {}),
  } as RegisterDriverResponse;
}

export function verifyTelemetrySignature(
  payload: TelemetryPayload,
  signature: string,
  publicKey: string
): boolean {
  const data = JSON.stringify(payload);
  try {
    const verify = createVerify('SHA256');
    verify.update(data);
    verify.end();
    return verify.verify(
      { key: Buffer.from(publicKey, 'hex'), format: 'der', type: 'spki' },
      signature,
      'base64'
    );
  } catch {
    return false;
  }
}

export function ingestSignedTelemetry(
  driverId: string,
  payload: TelemetryPayload,
  signature: string
): SignedTelemetry | null {
  const driver = drivers.get(driverId);
  if (!driver) return null;

  const verified = verifyTelemetrySignature(payload, signature, driver.publicKey);
  const record: SignedTelemetry = {
    id: uuidv4(),
    driverId,
    timestamp: new Date().toISOString(),
    payload,
    signature,
    signerAddress: driver.evmAddress,
    verified,
  };

  telemetryStore.push(record);

  const contrib = contributions.get(driverId)!;
  contrib.totalSignedRecords++;
  if (verified) {
    contrib.verifiedRecords++;
    contrib.shardContributions[payload.shardId] =
      (contrib.shardContributions[payload.shardId] || 0) + 1;
    contrib.estimatedRewardsUsd += 0.001;
    contrib.estimatedDepinRewards += 0.0005;
    contrib.lastContributionAt = new Date().toISOString();
  }

  return record;
}

export function getDriver(driverId: string): DriverIdentity | undefined {
  return drivers.get(driverId);
}

export function getContribution(driverId: string): DriverContribution | undefined {
  return contributions.get(driverId);
}

export function listTelemetry(driverId: string, limit = 50): SignedTelemetry[] {
  return telemetryStore.filter((t) => t.driverId === driverId).slice(-limit);
}

export function signPayloadDev(payload: TelemetryPayload, privateKeyHex: string): string {
  const sign = createSign('SHA256');
  sign.update(JSON.stringify(payload));
  sign.end();
  return sign.sign(
    { key: Buffer.from(privateKeyHex, 'hex'), format: 'der', type: 'pkcs8' },
    'base64'
  );
}

export function computeShardId(latitude: number, longitude: number): number {
  const hash = createHash('sha256')
    .update(`${latitude},${longitude}`)
    .digest();
  return hash[0] % 120;
}
