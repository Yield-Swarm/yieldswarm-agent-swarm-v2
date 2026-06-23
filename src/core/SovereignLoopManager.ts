/**
 * SovereignLoopManager — Pentagramal 5-agent ring (Poseidon Delta Trident v3.05911111100).
 *
 * Workers synchronize on a SharedArrayBuffer system clock every SYSTEM_CLOCK_TICK_RATE ms.
 */
import { Worker } from 'node:worker_threads';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORKER_PATH = resolve(__dirname, 'workers/tridentWorker.mjs');

export type WorkerKind =
  | 'sentinel'
  | 'nexus'
  | 'liquidity'
  | 'treasury'
  | 'codex';

export type AgentState = {
  kind: WorkerKind;
  ts: number;
  connected?: boolean;
  tunnelSilence?: boolean;
  kairosFrozen?: boolean;
  [key: string]: unknown;
};

export type SovereignLoopConfig = {
  tickRate: number;
  tridentVersion: string;
  vehicleId: string;
  lolminerPort: number;
  helixpowWssUrl?: string;
  heliomEdgeIngestKey?: string;
  codexPushEnabled: boolean;
};

const DEFAULT_CONFIG: SovereignLoopConfig = {
  tickRate: Number(process.env.SYSTEM_CLOCK_TICK_RATE ?? 5000),
  tridentVersion: process.env.TRIDENT_VERSION ?? '3.05911111100',
  vehicleId: process.env.VEHICLE_ID ?? 'APOLLO_NEXUS_TEST_01',
  lolminerPort: Number(process.env.LOLMINER_LOCAL_PORT ?? 4067),
  helixpowWssUrl: process.env.HELIXPOW_WSS_URL,
  heliomEdgeIngestKey: process.env.HELIOM_EDGE_INGEST_KEY,
  codexPushEnabled: process.env.CODEX_PUSH_ENABLED === '1',
};

export class SovereignLoopManager {
  private workers = new Map<WorkerKind, Worker>();
  private state = new Map<WorkerKind, AgentState>();
  private clock: SharedArrayBuffer;
  private clockView: BigInt64Array;
  private interval: NodeJS.Timeout | null = null;
  private readonly config: SovereignLoopConfig;

  constructor(config: Partial<SovereignLoopConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.clock = new SharedArrayBuffer(BigInt64Array.BYTES_PER_ELEMENT);
    this.clockView = new BigInt64Array(this.clock);
    this.clockView[0] = BigInt(Date.now());
  }

  start(): void {
    const kinds: WorkerKind[] = [
      'sentinel',
      'nexus',
      'liquidity',
      'treasury',
      'codex',
    ];
    const env = {
      TRIDENT_VERSION: this.config.tridentVersion,
      VEHICLE_ID: this.config.vehicleId,
      LOLMINER_LOCAL_PORT: String(this.config.lolminerPort),
      HELIXPOW_WSS_URL: this.config.helixpowWssUrl ?? '',
      HELIOM_EDGE_INGEST_KEY: this.config.heliomEdgeIngestKey ?? '',
      CODEX_PUSH_ENABLED: this.config.codexPushEnabled ? '1' : '0',
      SYSTEM_CLOCK_TICK_RATE: String(this.config.tickRate),
    };

    for (const kind of kinds) {
      const worker = new Worker(WORKER_PATH, {
        workerData: { kind, tickRate: this.config.tickRate, config: env },
      });
      worker.on('message', (msg: AgentState) => {
        this.state.set(kind, msg);
        if (kind === 'sentinel' && msg.tunnelSilence) {
          this.freezeKairosRisk();
        }
      });
      worker.on('error', (err) => {
        console.error(`[sovereign-loop] ${kind} error:`, err);
      });
      this.workers.set(kind, worker);
    }

    this.interval = setInterval(() => {
      this.clockView[0] = BigInt(Date.now());
      const snapshot = Object.fromEntries(this.state.entries());
      const codex = this.workers.get('codex');
      codex?.postMessage({ type: 'snapshot', snapshot });
    }, this.config.tickRate);

    console.error(
      `[sovereign-loop] Pentagramal ring live — tick=${this.config.tickRate}ms trident=${this.config.tridentVersion}`,
    );
  }

  freezeKairosRisk(): void {
    const treasury = this.workers.get('treasury');
    treasury?.postMessage({ type: 'freeze-kairos' });
    console.error(
      '[sovereign-loop] Sentinel tunnel silence — Kairos Risk Matrix frozen → USD1/USDC',
    );
  }

  getState(): Record<string, AgentState> {
    return Object.fromEntries(this.state.entries());
  }

  getClockMs(): number {
    return Number(this.clockView[0]);
  }

  async stop(): Promise<void> {
    if (this.interval) clearInterval(this.interval);
    await Promise.all(
      [...this.workers.values()].map(
        (w) => new Promise<void>((resolve) => w.once('exit', () => resolve())),
      ),
    );
    for (const w of this.workers.values()) w.terminate();
    this.workers.clear();
  }
}

if (import.meta.url === `file://${process.argv[1]?.replace(/\\/g, '/')}` || process.argv[1]?.endsWith('SovereignLoopManager.ts')) {
  const mgr = new SovereignLoopManager();
  mgr.start();
  process.on('SIGINT', () => {
    void mgr.stop().then(() => process.exit(0));
  });
}
