/**
 * Cryptographic signing for Kairo driving telemetry.
 *
 * Payloads are canonicalized JSON (sorted keys) then signed with the driver's
 * secp256k1 private key. Verification uses the registered public key / EVM address.
 */

import { Wallet, verifyMessage, hashMessage } from "ethers";
import { TelemetryPayload, SignedTelemetry } from "@/lib/kairo/models";
import { nowIso, uuid } from "@/lib/ids";

/** Canonical JSON with sorted keys for deterministic signing. */
export function canonicalizePayload(payload: TelemetryPayload): string {
  const sorted = Object.keys(payload)
    .sort()
    .reduce<Record<string, unknown>>((acc, key) => {
      acc[key] = (payload as Record<string, unknown>)[key];
      return acc;
    }, {});
  return JSON.stringify(sorted);
}

/** Sign telemetry on the driver device. */
export function signTelemetry(privateKey: string, payload: TelemetryPayload): string {
  const wallet = new Wallet(privateKey);
  return wallet.signMessageSync(canonicalizePayload(payload));
}

/** Verify a signature against the driver's registered EVM address. */
export function verifyTelemetrySignature(
  payload: TelemetryPayload,
  signature: string,
  signerAddress: string,
): boolean {
  try {
    const recovered = verifyMessage(canonicalizePayload(payload), signature);
    return recovered.toLowerCase() === signerAddress.toLowerCase();
  } catch {
    return false;
  }
}

export function payloadHash(payload: TelemetryPayload): string {
  return hashMessage(canonicalizePayload(payload));
}

export function buildSignedTelemetry(
  driverId: string,
  signerAddress: string,
  payload: TelemetryPayload,
  signature: string,
  verified: boolean,
  routing?: { mandelbrotShard?: number; treeOfLifeNode?: string },
): SignedTelemetry {
  return {
    id: uuid(),
    driverId,
    payload,
    signature,
    signerAddress,
    receivedAt: nowIso(),
    verified,
    mandelbrotShard: routing?.mandelbrotShard,
    treeOfLifeNode: routing?.treeOfLifeNode,
  };
}
