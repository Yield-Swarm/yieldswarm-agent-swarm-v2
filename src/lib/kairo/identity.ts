/**
 * Persistent cryptographic driver identity — IoTeX + EVM compatible.
 *
 * Both addresses derive from the same secp256k1 keypair. EVM uses standard
 * keccak256(pubkey) checksum address; IoTeX uses the same hash with an `io`
 * bech32 prefix (IoTeX mainnet).
 */

import { createHash, randomBytes, createHmac } from "node:crypto";
import { Wallet, computeAddress, SigningKey } from "ethers";
import { DriverIdentity } from "@/lib/kairo/models";
import { nowIso, uuid } from "@/lib/ids";

const IOTEX_HRP = "io";

/** Bech32 charset (BIP-173). */
const CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

function polymod(values: number[]): number {
  const GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
  let chk = 1;
  for (const v of values) {
    const top = chk >> 25;
    chk = ((chk & 0x1ffffff) << 5) ^ v;
    for (let i = 0; i < 5; i++) {
      if ((top >> i) & 1) chk ^= GEN[i]!;
    }
  }
  return chk;
}

function hrpExpand(hrp: string): number[] {
  const ret: number[] = [];
  for (let i = 0; i < hrp.length; i++) ret.push(hrp.charCodeAt(i) >> 5);
  ret.push(0);
  for (let i = 0; i < hrp.length; i++) ret.push(hrp.charCodeAt(i) & 31);
  return ret;
}

function createChecksum(hrp: string, data: number[]): number[] {
  const values = hrpExpand(hrp).concat(data).concat([0, 0, 0, 0, 0, 0]);
  const mod = polymod(values) ^ 1;
  const ret: number[] = [];
  for (let p = 0; p < 6; p++) ret.push((mod >> (5 * (5 - p))) & 31);
  return ret;
}

function bech32Encode(hrp: string, data: number[]): string {
  const combined = data.concat(createChecksum(hrp, data));
  return hrp + "1" + combined.map((d) => CHARSET[d]!).join("");
}

/** Convert 20-byte address hash to 5-bit groups for bech32. */
function toWords(bytes: Uint8Array): number[] {
  let acc = 0;
  let bits = 0;
  const ret: number[] = [];
  const maxv = 31;
  for (const v of bytes) {
    acc = (acc << 8) | v;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      ret.push((acc >> bits) & maxv);
    }
  }
  if (bits > 0) ret.push((acc << (5 - bits)) & maxv);
  return ret;
}

/** IoTeX address from the same private key as EVM (standard derivation). */
export function evmToIotexAddress(evmAddress: string): string {
  const hex = evmAddress.toLowerCase().replace(/^0x/, "");
  const bytes = Uint8Array.from(Buffer.from(hex, "hex"));
  return bech32Encode(IOTEX_HRP, toWords(bytes));
}

export function keyFingerprint(privateKey: string): string {
  return createHmac("sha256", "kairo-identity-v1")
    .update(privateKey)
    .digest("hex")
    .slice(0, 16);
}

export interface GeneratedIdentity {
  identity: DriverIdentity;
  /** Returned once at registration; store in Vault / secure enclave in production */
  privateKey: string;
}

/**
 * Generate a new persistent driver identity. The private key must be stored
 * securely on the driver device (Keychain / TEE) — never log or persist server-side.
 */
export function generateDriverIdentity(metadata?: Record<string, unknown>): GeneratedIdentity {
  const wallet = Wallet.createRandom();
  const publicKey = new SigningKey(wallet.privateKey).publicKey;
  const evmAddress = computeAddress(publicKey);
  const iotexAddress = evmToIotexAddress(evmAddress);

  const identity: DriverIdentity = {
    id: uuid(),
    evmAddress,
    iotexAddress,
    publicKey,
    keyFingerprint: keyFingerprint(wallet.privateKey),
    createdAt: nowIso(),
    metadata,
  };

  return { identity, privateKey: wallet.privateKey };
}

/** Re-derive addresses from an existing private key (device-side recovery). */
export function identityFromPrivateKey(
  privateKey: string,
  metadata?: Record<string, unknown>,
): GeneratedIdentity {
  const wallet = new Wallet(privateKey);
  const publicKey = new SigningKey(wallet.privateKey).publicKey;
  const evmAddress = computeAddress(publicKey);
  const iotexAddress = evmToIotexAddress(evmAddress);

  const identity: DriverIdentity = {
    id: uuid(),
    evmAddress,
    iotexAddress,
    publicKey,
    keyFingerprint: keyFingerprint(wallet.privateKey),
    createdAt: nowIso(),
    metadata,
  };

  return { identity, privateKey: wallet.privateKey };
}

/** Deterministic shard id for a driver (used by Mandelbrot router). */
export function driverShardIndex(driverId: string, shardCount = 120): number {
  const hash = createHash("sha256").update(driverId).digest();
  const n = hash.readUInt32BE(0);
  return n % shardCount;
}

/** Ephemeral device attestation nonce */
export function registrationNonce(): string {
  return randomBytes(16).toString("hex");
}
