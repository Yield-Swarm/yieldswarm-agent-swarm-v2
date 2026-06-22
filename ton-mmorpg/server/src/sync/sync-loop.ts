/**
 * Secure 7-step synchronization loop (server-authoritative).
 */

import { randomBytes } from "node:crypto";
import { computePoe, loadPoeConfigFromEnv } from "../poe/engine.js";
import { enforceRateLimit } from "../middleware/rate-limit.js";
import {
  loadTimestampReaderConfig,
  resolveAuthoritativeDeltaT,
} from "./timestamp-reader.js";

export interface SyncRequest {
  wallet: string;
  activityScore: number;
  sessionId?: string;
}

export interface SessionState {
  sessionId: string;
  wallet: string;
  accumulatedNanoThisSession: bigint;
  accumulatedIgjThisSession: bigint;
  lastSyncAt: number;
  lastProofHash: string;
}

export interface SyncResponse {
  ok: boolean;
  step: string;
  session: {
    sessionId: string;
    accumulatedNanoThisSession: string;
    accumulatedIgjThisSession: string;
  };
  proof: {
    deltaTSeconds: number;
    lastUpdateOnChain: number;
    deltaClamped: boolean;
    earnedNano: string;
    earnedIgj: string;
    capped: boolean;
    engine: {
      nanoPerSecond: string;
      activityMultiplier: number;
      rawNano: string;
    };
    settlementHash: string;
    syncedAt: number;
  };
  rateLimit: { remaining: number; resetAt: number };
}

const sessions = new Map<string, SessionState>();

function proofHash(wallet: string, nano: string, igj: string, ts: number): string {
  return randomBytes(16).toString("hex") + `-${wallet.slice(-6)}-${ts}`;
}

export async function runSyncLoop(req: SyncRequest): Promise<SyncResponse> {
  // Step 1: validate input (wallet present)
  if (!req.wallet || req.wallet.length < 10) {
    throw new Error("invalid wallet");
  }

  // Step 2: rate limit
  const rl = await enforceRateLimit(req.wallet);
  if (!rl.allowed) {
    const err = new Error("rate limit exceeded");
    (err as Error & { statusCode: number }).statusCode = 429;
    throw err;
  }

  // Step 3: session
  const sessionId = req.sessionId || randomBytes(12).toString("hex");
  let session = sessions.get(sessionId);
  if (!session || session.wallet !== req.wallet) {
    session = {
      sessionId,
      wallet: req.wallet,
      accumulatedNanoThisSession: 0n,
      accumulatedIgjThisSession: 0n,
      lastSyncAt: 0,
      lastProofHash: "",
    };
    sessions.set(sessionId, session);
  }

  // Step 4–5: on-chain timestamp → Δt (never client deltaTime)
  const delta = await resolveAuthoritativeDeltaT(req.wallet, loadTimestampReaderConfig());

  // Step 6: PoE accrual
  const poe = computePoe(
    {
      deltaTSeconds: delta.deltaTSeconds,
      activityScore: req.activityScore,
      sessionAccumulatedNano: session.accumulatedNanoThisSession,
    },
    loadPoeConfigFromEnv(),
  );

  session.accumulatedNanoThisSession += poe.earnedNano;
  session.accumulatedIgjThisSession += poe.earnedIgj;
  const syncedAt = Math.floor(Date.now() / 1000);
  session.lastSyncAt = syncedAt;
  session.lastProofHash = proofHash(req.wallet, poe.earnedNano.toString(), poe.earnedIgj.toString(), syncedAt);

  // Step 7: settlement queue placeholder (on-chain tx submitted async in production)
  return {
    ok: true,
    step: "settled-pending-chain",
    session: {
      sessionId: session.sessionId,
      accumulatedNanoThisSession: session.accumulatedNanoThisSession.toString(),
      accumulatedIgjThisSession: session.accumulatedIgjThisSession.toString(),
    },
    proof: {
      deltaTSeconds: poe.deltaTSeconds,
      lastUpdateOnChain: delta.lastUpdateOnChain,
      deltaClamped: delta.clamped,
      earnedNano: poe.earnedNano.toString(),
      earnedIgj: poe.earnedIgj.toString(),
      capped: poe.capped,
      engine: poe.engine,
      settlementHash: session.lastProofHash,
      syncedAt,
    },
    rateLimit: { remaining: rl.remaining, resetAt: rl.resetAt },
  };
}

export function getSession(sessionId: string): SessionState | undefined {
  return sessions.get(sessionId);
}
