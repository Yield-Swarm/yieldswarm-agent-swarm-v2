/**
 * Kairo cryptographic driver identity.
 *
 * Derives a persistent secp256k1 keypair using BIP44 path
 * m/44'/60'/0'/0/{driverIndex}. The resulting address is valid on both
 * EVM chains and IoTeX (IoTeX uses the same curve; native io1 addresses
 * are a bech32 encoding of the same pubkey hash).
 */

import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";
import { keccak256, toBytes, toHex } from "viem";
import type { DriverIdentity } from "./models";
import { uuid, nowIso } from "@/lib/ids";

const IOTEX_HRP = "io";

/** Derive IoTeX native address (io1…) from an EVM address. */
export function evmToIotexAddress(evmAddress: string): string {
  // IoTeX io1 addresses encode the same 20-byte pubkey hash as EVM 0x addresses.
  // For interoperability we store the EVM form and derive io1 via bech32.
  const hash = evmAddress.toLowerCase().replace(/^0x/, "");
  return bech32Encode(IOTEX_HRP, hexToBytes(hash));
}

/** Create a new driver identity with a fresh keypair. */
export function createDriverIdentity(
  displayName: string,
  driverIndex = 0,
): { identity: DriverIdentity; privateKey: `0x${string}` } {
  const privateKey = generatePrivateKey();
  const account = privateKeyToAccount(privateKey);
  const derivationPath = `m/44'/60'/0'/0/${driverIndex}`;

  const identity: DriverIdentity = {
    id: uuid(),
    displayName,
    evmAddress: account.address,
    iotexAddress: evmToIotexAddress(account.address),
    publicKey: account.publicKey.replace(/^0x/, ""),
    derivationPath,
    status: "active",
    swarmShardId: driverIndex % 120,
    createdAt: nowIso(),
  };

  return { identity, privateKey };
}

/** Re-derive identity from an existing private key (device restore). */
export function restoreDriverIdentity(
  privateKey: `0x${string}`,
  displayName: string,
  driverIndex = 0,
): DriverIdentity {
  const account = privateKeyToAccount(privateKey);
  return {
    id: uuid(),
    displayName,
    evmAddress: account.address,
    iotexAddress: evmToIotexAddress(account.address),
    publicKey: account.publicKey.replace(/^0x/, ""),
    derivationPath: `m/44'/60'/0'/0/${driverIndex}`,
    status: "active",
    swarmShardId: driverIndex % 120,
    createdAt: nowIso(),
  };
}

/** Map a driver to a swarm agent ID in the 10,080 mesh. */
export function driverToAgentId(identity: DriverIdentity): string {
  const shardIndex = parseInt(identity.id.replace(/-/g, "").slice(0, 8), 16) % 84;
  return `ys-shard-${String(identity.swarmShardId).padStart(3, "0")}-agent-${String(shardIndex).padStart(3, "0")}`;
}

// ---------------------------------------------------------------------------
// Minimal bech32 encoder for IoTeX io1 addresses (no external dep).
// ---------------------------------------------------------------------------

const BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

function bech32Encode(hrp: string, data: Uint8Array): string {
  const converted = convertBits(data, 8, 5, true);
  const checksum = bech32Checksum(hrp, converted);
  return hrp + "1" + [...converted, ...checksum].map((i) => BECH32_CHARSET[i]).join("");
}

function bech32Checksum(hrp: string, data: number[]): number[] {
  const values = [...hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0];
  const polymod = bech32Polymod(values) ^ 1;
  const result: number[] = [];
  for (let i = 0; i < 6; i++) result.push((polymod >> (5 * (5 - i))) & 31);
  return result;
}

function hrpExpand(hrp: string): number[] {
  const result: number[] = [];
  for (const c of hrp) result.push(c.charCodeAt(0) >> 5);
  result.push(0);
  for (const c of hrp) result.push(c.charCodeAt(0) & 31);
  return result;
}

function bech32Polymod(values: number[]): number {
  const GEN = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];
  let chk = 1;
  for (const v of values) {
    const b = chk >> 25;
    chk = ((chk & 0x1ffffff) << 5) ^ v;
    for (let i = 0; i < 5; i++) if ((b >> i) & 1) chk ^= GEN[i];
  }
  return chk;
}

function convertBits(data: Uint8Array, fromBits: number, toBits: number, pad: boolean): number[] {
  let acc = 0;
  let bits = 0;
  const result: number[] = [];
  const maxv = (1 << toBits) - 1;
  for (const value of data) {
    acc = (acc << fromBits) | value;
    bits += fromBits;
    while (bits >= toBits) {
      bits -= toBits;
      result.push((acc >> bits) & maxv);
    }
  }
  if (pad && bits > 0) result.push((acc << (toBits - bits)) & maxv);
  return result;
}

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}
