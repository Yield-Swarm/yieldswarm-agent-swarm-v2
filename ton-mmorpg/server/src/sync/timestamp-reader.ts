/**
 * Read PlayerSBT last_update timestamp from TON mainnet/testnet.
 * Server MUST use this — never trust client-supplied deltaTime.
 */

import { Address, beginCell, TupleReader } from "@ton/core";
import { TonClient } from "@ton/ton";

export interface TimestampReaderConfig {
  rpcEndpoint: string;
  apiKey?: string;
  playerSbtAddress: string;
  maxDeltaTSeconds: number;
}

export interface DeltaTResult {
  lastUpdateOnChain: number;
  serverNow: number;
  deltaTSeconds: number;
  clamped: boolean;
  source: "on-chain" | "fallback-genesis";
}

const GET_LAST_UPDATE_OPCODE = "last_update";

export function loadTimestampReaderConfig(): TimestampReaderConfig {
  return {
    rpcEndpoint: process.env.TON_RPC_ENDPOINT || "https://toncenter.com/api/v2/jsonRPC",
    apiKey: process.env.TONCENTER_API_KEY,
    playerSbtAddress: process.env.PLAYER_SBT_ADDRESS || "",
    maxDeltaTSeconds: Number(process.env.MAX_DELTA_T_SECONDS || "3600"),
  };
}

export function createTonClient(config: TimestampReaderConfig): TonClient {
  return new TonClient({
    endpoint: config.rpcEndpoint,
    apiKey: config.apiKey,
  });
}

/** Parse get-method stack: expects single int (unix seconds). */
export function parseLastUpdateStack(reader: TupleReader): number {
  try {
    const v = reader.readBigNumber();
    return Number(v);
  } catch {
    const v = reader.readNumber();
    return v;
  }
}

/**
 * Call PlayerSBT get-method `last_update(owner)` or `get_player_data`.
 * Contract must expose consistent getter — see contracts/tact/PlayerSBT.tact.
 */
export async function readLastUpdateOnChain(
  walletAddress: string,
  config: TimestampReaderConfig,
  client?: TonClient,
): Promise<number> {
  if (!config.playerSbtAddress) {
    throw new Error("PLAYER_SBT_ADDRESS not configured");
  }

  const ton = client ?? createTonClient(config);
  const sbt = Address.parse(config.playerSbtAddress);
  const owner = Address.parse(walletAddress);

  const { stack } = await ton.runMethod(sbt, GET_LAST_UPDATE_OPCODE, [
    { type: "slice", cell: beginCell().storeAddress(owner).endCell() },
  ]);

  return parseLastUpdateStack(stack);
}

/**
 * Compute server-authoritative Δt with clamp.
 */
export function computeDeltaT(
  lastUpdateOnChain: number,
  serverNowSec: number = Math.floor(Date.now() / 1000),
  maxDeltaT: number = 3600,
): DeltaTResult {
  const raw = Math.max(0, serverNowSec - lastUpdateOnChain);
  const clamped = raw > maxDeltaT;
  return {
    lastUpdateOnChain,
    serverNow: serverNowSec,
    deltaTSeconds: clamped ? maxDeltaT : raw,
    clamped,
    source: "on-chain",
  };
}

export async function resolveAuthoritativeDeltaT(
  walletAddress: string,
  config?: TimestampReaderConfig,
): Promise<DeltaTResult> {
  const cfg = config ?? loadTimestampReaderConfig();
  const now = Math.floor(Date.now() / 1000);

  if (!cfg.playerSbtAddress) {
    return {
      lastUpdateOnChain: now,
      serverNow: now,
      deltaTSeconds: 0,
      clamped: false,
      source: "fallback-genesis",
    };
  }

  const lastUpdate = await readLastUpdateOnChain(walletAddress, cfg);
  return computeDeltaT(lastUpdate, now, cfg.maxDeltaTSeconds);
}
