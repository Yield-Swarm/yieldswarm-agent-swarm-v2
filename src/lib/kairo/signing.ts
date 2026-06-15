/**
 * Cryptographic signing and verification for Kairo driver telemetry.
 *
 * Events are signed with the driver's secp256k1 private key. The canonical
 * message is keccak256(JSON.stringify(payload, sorted keys)).
 */

import { privateKeyToAccount, type PrivateKeyAccount } from "viem/accounts";
import { keccak256, toBytes, recoverMessageAddress } from "viem";
import type { SignedTelemetryEvent } from "./models";
import { uuid, nowIso } from "@/lib/ids";

/** Build the canonical message bytes for signing / verification. */
export function canonicalMessage(
  driverId: string,
  eventType: string,
  timestamp: string,
  payload: Record<string, unknown>,
): `0x${string}` {
  const body = JSON.stringify({ driverId, eventType, timestamp, payload }, Object.keys({ driverId: 1, eventType: 1, timestamp: 1, payload: 1 }).sort());
  return keccak256(toBytes(body));
}

/** Sign a telemetry event with the driver's private key. */
export async function signTelemetryEvent(
  account: PrivateKeyAccount,
  driverId: string,
  eventType: string,
  timestamp: string,
  payload: Record<string, unknown>,
): Promise<SignedTelemetryEvent> {
  const message = canonicalMessage(driverId, eventType, timestamp, payload);
  const signature = await account.signMessage({ message: { raw: toBytes(message) } });

  return {
    id: uuid(),
    driverId,
    eventType,
    timestamp,
    payload,
    signature,
    signerAddress: account.address,
  };
}

/** Verify that a telemetry event was signed by the claimed address. */
export async function verifyTelemetrySignature(
  event: SignedTelemetryEvent,
): Promise<boolean> {
  try {
    const message = canonicalMessage(
      event.driverId,
      event.eventType,
      event.timestamp,
      event.payload,
    );
    const recovered = await recoverMessageAddress({
      message: { raw: toBytes(message) },
      signature: event.signature as `0x${string}`,
    });
    return recovered.toLowerCase() === event.signerAddress.toLowerCase();
  } catch {
    return false;
  }
}

/** Convenience: sign from a raw private key hex string. */
export async function signFromPrivateKey(
  privateKey: `0x${string}`,
  driverId: string,
  eventType: string,
  payload: Record<string, unknown>,
): Promise<SignedTelemetryEvent> {
  const account = privateKeyToAccount(privateKey);
  return signTelemetryEvent(account, driverId, eventType, nowIso(), payload);
}
