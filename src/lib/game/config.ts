/**
 * TON MMORPG — authoritative server configuration (Layer 2).
 */
import { bool } from "@/lib/config/env-helpers";

function gameStr(name: string, fallback = ""): string {
  return process.env[name]?.trim() || fallback;
}

export const gameEnv = {
  /** PlayerSBT / PlayerRegistry contract on TON mainnet or testnet. */
  playerSbtAddress: () => gameStr("PLAYERSBT_CONTRACT_ADDRESS"),
  /** InGameJetton master for IGJ mints. */
  jettonMasterAddress: () => gameStr("IGJ_JETTON_MASTER_ADDRESS"),
  /** Ed25519 server signing key (64-byte hex = seed + public, or 32-byte seed PKCS8 export). */
  settlementPrivateKeyHex: () => gameStr("GAME_SETTLEMENT_PRIVATE_KEY_HEX"),
  /** Published on-chain in PlayerSBT for signature verification. */
  settlementPublicKeyHex: () => gameStr("GAME_SETTLEMENT_PUBLIC_KEY_HEX"),
  /** Nanoton attached to claim message (~0.05 TON). */
  claimValueNanoton: () => gameStr("GAME_CLAIM_VALUE_NANOTON", "50000000"),
  /** Max claims per wallet per window. */
  rateLimitMax: () => Number(gameStr("GAME_RATE_LIMIT_MAX", "12")) || 12,
  /** Rate limit window in seconds. */
  rateLimitWindowSec: () => Number(gameStr("GAME_RATE_LIMIT_WINDOW_SEC", "60")) || 60,
  /** Upstash Redis REST (optional — in-memory fallback in dev). */
  redisUrl: () => gameStr("UPSTASH_REDIS_REST_URL"),
  redisToken: () => gameStr("UPSTASH_REDIS_REST_TOKEN"),
  /** Allow client-reported Δt when contract/RPC unavailable (dev only). */
  allowClientDelta: () => bool("GAME_ALLOW_CLIENT_DELTA", process.env.NODE_ENV !== "production"),
  tonApiBase: () => gameStr("TON_API_BASE", "https://tonapi.io"),
  tonApiKey: () => gameStr("TON_API_KEY"),
};

/** Claim opcode — must match PlayerSBT.tact `OP_CLAIM`. */
export const OP_CLAIM = 0x434c4149; // "CLAI"
