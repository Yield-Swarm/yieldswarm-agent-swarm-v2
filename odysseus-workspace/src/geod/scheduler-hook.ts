/**
 * GEOD (Geospatial-Entropy Distributed) cron scheduler hook.
 * Attaches post-initialization lifecycle for entropy shard harvesting.
 */

import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import cron from "node-cron";
import type { GeodConfig, OdysseusRuntime } from "../config/types.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");

export interface GeodTickResult {
  ok: boolean;
  stdout: string;
  stderr: string;
  code: number | null;
}

export interface GeodSchedulerHook {
  /** Called immediately after Odysseus workspace bootstrap completes. */
  onPostInit(runtime: OdysseusRuntime): Promise<void>;
}

export class PythonGeodSchedulerHook implements GeodSchedulerHook {
  constructor(
    private readonly repoRoot: string = REPO_ROOT,
    private readonly pythonBin = process.env.PYTHON_BIN || "python3",
  ) {}

  async runTick(): Promise<GeodTickResult> {
    const script = path.join(this.repoRoot, "services", "geod", "scheduler.py");
    return new Promise((resolve) => {
      const child = spawn(this.pythonBin, [script, "--tick"], {
        cwd: this.repoRoot,
        env: { ...process.env, PYTHONPATH: this.repoRoot },
      });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (d) => { stdout += d; });
      child.stderr.on("data", (d) => { stderr += d; });
      child.on("close", (code) => {
        resolve({ ok: code === 0, stdout, stderr, code });
      });
      child.on("error", (err) => {
        resolve({ ok: false, stdout, stderr: String(err), code: null });
      });
    });
  }

  async onPostInit(runtime: OdysseusRuntime): Promise<void> {
    const geod: GeodConfig = runtime.config.geod;
    if (!geod.enabled) {
      console.info("[geod] scheduler disabled (GEOD_CRON_ENABLED=false)");
      return;
    }

    if (!cron.validate(geod.cronExpression)) {
      throw new Error(`Invalid GEOD_CRON_EXPRESSION: ${geod.cronExpression}`);
    }

    console.info(
      `[geod] attaching cron '${geod.cronExpression}' shards=${geod.entropyShardCount}`,
    );

    const tick = async () => {
      const result = await this.runTick();
      if (!result.ok) {
        console.error("[geod] tick failed", result.stderr || result.stdout);
        return;
      }
      const line = result.stdout.trim().split("\n").pop();
      if (line) console.info(`[geod] ${line}`);
    };

    await tick();
    cron.schedule(geod.cronExpression, () => {
      void tick();
    });
  }
}

export async function attachGeodScheduler(
  runtime: OdysseusRuntime,
  hook: GeodSchedulerHook = new PythonGeodSchedulerHook(),
): Promise<void> {
  await hook.onPostInit(runtime);
}
