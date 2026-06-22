/**
 * Authoritative settlement pipeline (Layer 2).
 *
 * 1. Rate limit (Redis token bucket)
 * 2. On-chain timestamp fetch (TON RPC)
 * 3. PoE fixed-point calculation (bigint)
 * 4. Ed25519 sign + BOC serialize
 * 5. Return payload for TonConnect wallet broadcast (Layer 3)
 */
import { calculatePoEEmission, emissionNanoToDisplay } from "@/lib/game/engine";
import { checkClaimRateLimit } from "@/lib/game/rate-limit";
import { deriveDeltaTime, fetchOnChainPlayerState } from "@/lib/game/ton-chain";
import { signSettlementPayload, type SettlementPayload } from "@/lib/game/signing";
import { buildClaimSettlementCell } from "@/lib/game/settlement-cell";
import { gameEnv } from "@/lib/game/config";
import type { ClaimRequest } from "@/types/game";

export type PipelineErrorCode =
  | "RATE_LIMITED"
  | "CLOCK_SKEW"
  | "INVALID_STATE"
  | "SETTLEMENT_NOT_CONFIGURED";

export interface SettlementResult {
  success: true;
  securedState: {
    wallet: string;
    level: number;
    equipmentHash: string;
    chainTimestamp: number;
    deltaTime: number;
  };
  emissionNano: string;
  emissionDisplay: number;
  signature: string;
  settlement?: {
    contractAddress: string;
    valueNanoton: string;
    bocBase64: string;
  };
  msg: string;
}

export interface PipelineFailure {
  success: false;
  code: PipelineErrorCode;
  error: string;
  retryAfterSec?: number;
}

export async function runSettlementPipeline(
  request: ClaimRequest,
): Promise<SettlementResult | PipelineFailure> {
  const wallet = request.player.walletAddress;
  const serverNow = Math.floor(Date.now() / 1000);

  const rate = await checkClaimRateLimit(wallet);
  if (!rate.allowed) {
    return {
      success: false,
      code: "RATE_LIMITED",
      error: "Claim rate limit exceeded",
      retryAfterSec: rate.retryAfterSec,
    };
  }

  const onChain = await fetchOnChainPlayerState(wallet);
  let deltaTime = deriveDeltaTime(onChain.lastSaveTimestamp, serverNow);

  if (request.clientTimestamp && gameEnv.allowClientDelta()) {
    const clientDelta = serverNow - request.clientTimestamp;
    if (clientDelta > 0 && clientDelta < deltaTime) {
      deltaTime = Math.min(Math.max(clientDelta, 1), 3600);
    }
  }

  if (
    onChain.source === "tonapi" &&
    request.player.lastSaveTimestamp &&
    request.player.lastSaveTimestamp > onChain.lastSaveTimestamp + 300
  ) {
    return {
      success: false,
      code: "CLOCK_SKEW",
      error: "Client timestamp ahead of on-chain state",
    };
  }

  const action = {
    ...request.action,
    deltaTime,
  };

  const emissionNano = calculatePoEEmission(action);
  const settlementPayload: SettlementPayload = {
    wallet,
    level: request.player.level,
    equipmentHash: request.player.equipmentHash,
    emissionNano: emissionNano.toString(),
    chainTimestamp: onChain.lastSaveTimestamp,
    serverTimestamp: serverNow,
    deltaTime,
    actionType: request.action.actionType,
  };

  const signature = signSettlementPayload(settlementPayload);

  let settlement: SettlementResult["settlement"];
  if (gameEnv.playerSbtAddress()) {
    try {
      const cell = buildClaimSettlementCell(settlementPayload, signature);
      settlement = {
        contractAddress: cell.contractAddress,
        valueNanoton: cell.valueNanoton,
        bocBase64: cell.bocBase64,
      };
    } catch (err) {
      return {
        success: false,
        code: "SETTLEMENT_NOT_CONFIGURED",
        error: err instanceof Error ? err.message : "Settlement cell build failed",
      };
    }
  }

  return {
    success: true,
    securedState: {
      wallet,
      level: request.player.level,
      equipmentHash: request.player.equipmentHash,
      chainTimestamp: onChain.lastSaveTimestamp,
      deltaTime,
    },
    emissionNano: emissionNano.toString(),
    emissionDisplay: emissionNanoToDisplay(emissionNano),
    signature,
    settlement,
    msg: settlement
      ? "Signed settlement cell ready for TonConnect broadcast."
      : "Authorization signed (configure PLAYERSBT_CONTRACT_ADDRESS for on-chain settlement).",
  };
}
