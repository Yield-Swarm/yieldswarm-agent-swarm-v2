import { createHmac, timingSafeEqual } from "node:crypto";
import { serverEnv } from "@/lib/config/env";

export type ClaimSignaturePayload = {
  recipient: string;
  amount: string;
  actionHash: string;
  nonce: number;
  timestamp: number;
};

function signingSecret(): string {
  const secret = serverEnv.claim.signingSecret();
  if (!secret && process.env.NODE_ENV === "production") {
    throw new Error("CLAIM_SIGNING_SECRET is required in production");
  }
  return secret || "yieldswarm-dev-claim-signing-secret";
}

function canonicalMessage(payload: ClaimSignaturePayload): string {
  return [
    payload.recipient,
    payload.amount,
    payload.actionHash,
    String(payload.nonce),
    String(payload.timestamp),
  ].join(":");
}

/** HMAC-SHA256 authorization for jetton contract claim messages. */
export function signClaimPayload(payload: ClaimSignaturePayload): string {
  return createHmac("sha256", signingSecret())
    .update(canonicalMessage(payload))
    .digest("hex");
}

export function verifyClaimPayload(
  payload: ClaimSignaturePayload,
  signature: string,
): boolean {
  try {
    const expected = Buffer.from(signClaimPayload(payload), "hex");
    const actual = Buffer.from(signature, "hex");
    if (expected.length !== actual.length) return false;
    return timingSafeEqual(expected, actual);
  } catch {
    return false;
  }
}
