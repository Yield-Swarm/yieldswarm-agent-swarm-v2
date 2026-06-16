import fs from "node:fs/promises";
import path from "node:path";
import { ok } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const DEFAULT_STATE = {
  activated: false,
  phase: "genesis-pending",
  genesisHash: null,
  activatedAt: null,
  yslr: { phase: "pending", signalsProcessed: 0, lastSignalAt: null },
  readinessScore: 72,
};

/** GET /api/helix/status — Helix Chain activation for council + static pages */
export async function GET() {
  const statePath = path.join(process.cwd(), "dashboard", "helix-state.json");
  let state: typeof DEFAULT_STATE & Record<string, unknown> = { ...DEFAULT_STATE };
  try {
    const raw = await fs.readFile(statePath, "utf8");
    state = { ...state, ...JSON.parse(raw) };
  } catch {
    /* use defaults */
  }

  return ok({
    ...state,
    generatedAt: new Date().toISOString(),
    onChainReceipts: {
      emissionRouter: { connected: Boolean(process.env.YIELDSWARM_EMISSION_ROUTER_ADDRESS) },
      treasuryNavUsd: 5_000_000,
    },
  });
}
