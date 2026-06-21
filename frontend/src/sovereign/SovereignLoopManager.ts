import { create } from "zustand";

export type SovereignLog = {
  type: string;
  message: string;
  timestamp: string;
};

export type SovereignTreasuries = {
  nexus?: number;
  helix?: number;
  shadow?: number;
};

type SovereignLoopsState = {
  currentState: string;
  logs: SovereignLog[];
  treasuries: SovereignTreasuries;
  totalTreasury: number;
  penningTrapIntegrity: number;
  replicationSurplus: number;
  loading: boolean;
  error: string | null;
  focused: boolean;
  refresh: () => Promise<void>;
  setFocused: (value: boolean) => void;
  manualActions: {
    forceRebalance: () => Promise<void>;
    forceReplicate: () => Promise<void>;
    triggerPatch: () => Promise<void>;
  };
};

const TICK_RATE = Number(import.meta.env.VITE_SYSTEM_CLOCK_TICK_RATE || 1000);

function applyPayload(
  set: (partial: Partial<SovereignLoopsState>) => void,
  payload: Record<string, unknown>,
) {
  set({
    currentState: String(payload.currentState ?? "Nominal"),
    logs: Array.isArray(payload.logs) ? (payload.logs as SovereignLog[]) : [],
    treasuries: (payload.treasuries as SovereignTreasuries) ?? {},
    totalTreasury: Number(payload.totalTreasury ?? 0),
    penningTrapIntegrity: Number(payload.penningTrapIntegrity ?? 99.99995),
    replicationSurplus: Number(payload.replicationSurplus ?? 0),
    loading: false,
    error: null,
  });
}

async function postAction(path: string) {
  const res = await fetch(path, { method: "POST" });
  if (!res.ok) throw new Error(`${path} ${res.status}`);
  return res.json() as Promise<Record<string, unknown>>;
}

export const useSovereignLoopsStore = create<SovereignLoopsState>((set, get) => ({
  currentState: "Nominal",
  logs: [],
  treasuries: {},
  totalTreasury: 0,
  penningTrapIntegrity: 99.99995,
  replicationSurplus: 0,
  loading: true,
  error: null,
  focused: false,

  setFocused: (value) => set({ focused: value }),

  refresh: async () => {
    try {
      const res = await fetch("/api/sovereign/loops", { cache: "no-store" });
      if (!res.ok) throw new Error(`loops ${res.status}`);
      const payload = (await res.json()) as Record<string, unknown>;
      applyPayload(set, payload);
    } catch (err) {
      set({
        loading: false,
        error: err instanceof Error ? err.message : "sovereign loops unavailable",
      });
    }
  },

  manualActions: {
    forceRebalance: async () => {
      const payload = await postAction("/api/sovereign/loops/rebalance");
      applyPayload(set, payload);
    },
    forceReplicate: async () => {
      const payload = await postAction("/api/sovereign/loops/replicate");
      applyPayload(set, payload);
    },
    triggerPatch: async () => {
      const payload = await postAction("/api/sovereign/loops/patch");
      applyPayload(set, payload);
    },
  },
}));

/** Hook consumed by SovereignLoopsPanel — polls sovereign loop telemetry. */
export function useSovereignLoops() {
  const store = useSovereignLoopsStore();
  return store;
}

let pollStarted = false;

export function startSovereignLoopsPolling() {
  if (pollStarted || typeof window === "undefined") return;
  pollStarted = true;
  const tick = () => void useSovereignLoopsStore.getState().refresh();
  tick();
  window.setInterval(tick, TICK_RATE);
}
