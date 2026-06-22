/**
 * TON mainnet RPC — fetch tamper-proof on-chain last-save timestamp (Step 2).
 */
import { gameEnv } from "@/lib/game/config";

export interface OnChainPlayerState {
  lastSaveTimestamp: number;
  level: number;
  equipmentHash: string;
  source: "tonapi" | "genesis" | "cache";
}

const CACHE_TTL_MS = 15_000;
const stateCache = new Map<string, { at: number; state: OnChainPlayerState }>();

function tonHeaders(): HeadersInit {
  const headers: HeadersInit = { Accept: "application/json" };
  const key = gameEnv.tonApiKey();
  if (key) headers.Authorization = `Bearer ${key}`;
  return headers;
}

/**
 * Query PlayerSBT `get_player_state` via tonapi exec endpoint.
 * Returns timestamp 0 when contract is not deployed (genesis claim).
 */
export async function fetchOnChainPlayerState(wallet: string): Promise<OnChainPlayerState> {
  const cached = stateCache.get(wallet);
  if (cached && Date.now() - cached.at < CACHE_TTL_MS) {
    return { ...cached.state, source: "cache" };
  }

  const contract = gameEnv.playerSbtAddress();
  if (!contract) {
    return {
      lastSaveTimestamp: 0,
      level: 1,
      equipmentHash: "0".repeat(64),
      source: "genesis",
    };
  }

  const base = gameEnv.tonApiBase().replace(/\/$/, "");
  const url = `${base}/v2/blockchain/accounts/${contract}/methods/get_player_state`;

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { ...tonHeaders(), "Content-Type": "application/json" },
      body: JSON.stringify({
        args: [{ type: "slice", value: wallet }],
      }),
      next: { revalidate: 0 },
    });

    if (!res.ok) {
      if (res.status === 404) {
        return {
          lastSaveTimestamp: 0,
          level: 1,
          equipmentHash: "0".repeat(64),
          source: "genesis",
        };
      }
      throw new Error(`tonapi ${res.status}: ${await res.text()}`);
    }

    const data = (await res.json()) as {
      stack?: Array<{ type: string; num?: string; hex?: string }>;
    };

    const stack = data.stack ?? [];
    const ts = Number(stack[0]?.num ?? "0");
    const level = Number(stack[1]?.num ?? "1");
    const equipHex = (stack[2]?.hex ?? "").replace(/^0x/, "").padStart(64, "0").slice(-64);

    const state: OnChainPlayerState = {
      lastSaveTimestamp: ts,
      level,
      equipmentHash: equipHex,
      source: "tonapi",
    };
    stateCache.set(wallet, { at: Date.now(), state });
    return state;
  } catch {
    return {
      lastSaveTimestamp: 0,
      level: 1,
      equipmentHash: "0".repeat(64),
      source: "genesis",
    };
  }
}

/** Derive tamper-proof Δt from on-chain timestamp vs server clock. */
export function deriveDeltaTime(onChainLastSave: number, serverNowSec: number): number {
  if (onChainLastSave <= 0) return 1;
  const raw = serverNowSec - onChainLastSave;
  return Math.min(Math.max(raw, 1), 3600);
}
