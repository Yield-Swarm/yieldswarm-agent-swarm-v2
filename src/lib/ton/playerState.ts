import { Address, beginCell, TonClient } from "@ton/ton";
import { TON_CONFIG } from "@/lib/ton/config";
import type { PlayerProfile } from "@/types/game";
import { POE_DEFAULT_DELTA_SECONDS } from "@/lib/game/engine";

let _client: TonClient | null = null;

function getTonClient(): TonClient {
  if (!_client) {
    _client = new TonClient({
      endpoint: TON_CONFIG.rpcEndpoint,
      apiKey: TON_CONFIG.apiKey || undefined,
    });
  }
  return _client;
}

type PlayerStateResult = {
  lastSaveTimestamp: number;
  source: "indexer" | "rpc" | "fallback";
};

/**
 * Fetch authoritative lastSaveTimestamp for a wallet.
 * Priority: indexer → on-chain get-method → safe baseline.
 */
export async function fetchPlayerLastSaveTimestamp(
  walletAddress: string,
): Promise<PlayerStateResult> {
  const fromIndexer = await fetchFromIndexer(walletAddress);
  if (fromIndexer !== null) {
    return { lastSaveTimestamp: fromIndexer, source: "indexer" };
  }

  const fromRpc = await fetchFromRpc(walletAddress);
  if (fromRpc !== null) {
    return { lastSaveTimestamp: fromRpc, source: "rpc" };
  }

  return { lastSaveTimestamp: 0, source: "fallback" };
}

async function fetchFromIndexer(walletAddress: string): Promise<number | null> {
  const base = TON_CONFIG.indexerBase?.replace(/\/$/, "");
  if (!base) return null;

  try {
    const url = `${base}/v2/game/players/${encodeURIComponent(walletAddress)}`;
    const headers: Record<string, string> = { Accept: "application/json" };
    if (TON_CONFIG.apiKey) headers.Authorization = `Bearer ${TON_CONFIG.apiKey}`;

    const res = await fetch(url, { headers, signal: AbortSignal.timeout(8_000) });
    if (!res.ok) return null;

    const data = (await res.json()) as Partial<PlayerProfile>;
    if (typeof data.lastSaveTimestamp === "number" && data.lastSaveTimestamp > 0) {
      return data.lastSaveTimestamp;
    }
  } catch {
    /* indexer unavailable — fall through */
  }
  return null;
}

async function fetchFromRpc(walletAddress: string): Promise<number | null> {
  const contract = TON_CONFIG.contracts.sbt;
  if (!contract) return null;

  try {
    const client = getTonClient();
    const addr = Address.parse(contract);

    // Per-wallet getter when contract supports wallet slice argument.
    try {
      const perWallet = await client.runMethod(addr, "get_player_state", [
        {
          type: "slice",
          cell: beginCell().storeAddress(Address.parse(walletAddress)).endCell(),
        },
      ]);
      return readLastSaveFromStack(perWallet);
    } catch {
      /* try global getter */
    }

    const global = await client.runMethod(addr, "getCharacterState");
    return readLastSaveFromStack(global);
  } catch (err) {
    console.warn(
      `[RPC] Could not fetch SBT state for ${walletAddress}:`,
      err instanceof Error ? err.message : err,
    );
    return null;
  }
}

function readLastSaveFromStack(result: {
  stack: {
    skip(n: number): void;
    readNumber(): number;
  };
}): number | null {
  try {
    result.stack.skip(3);
    const ts = result.stack.readNumber();
    return ts > 0 ? ts : null;
  } catch {
    return null;
  }
}

export function resolveDeltaTime(
  lastSaveTimestamp: number,
  currentUnixTime: number,
): number {
  if (lastSaveTimestamp <= 0) return POE_DEFAULT_DELTA_SECONDS;
  const delta = Math.max(0, currentUnixTime - lastSaveTimestamp);
  return Math.min(delta, TON_CONFIG.claim.maxDeltaSeconds);
}
