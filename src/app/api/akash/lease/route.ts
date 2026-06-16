import { NextResponse } from "next/server";
import { readFile } from "node:fs/promises";
import path from "node:path";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const RUN_DIR = path.join(process.cwd(), ".run");

function parseLeaseEnv(content: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }
    const eq = trimmed.indexOf("=");
    if (eq <= 0) {
      continue;
    }
    out[trimmed.slice(0, eq)] = trimmed.slice(eq + 1);
  }
  return out;
}

/** Expose live Akash lease worker URLs from `.run/akash-lease.env` (server-side only). */
export async function GET() {
  const leaseEnvPath = path.join(RUN_DIR, "akash-lease.env");
  const deployJsonPath = path.join(RUN_DIR, "akash-deploy.json");

  try {
    const envRaw = await readFile(leaseEnvPath, "utf8");
    const env = parseLeaseEnv(envRaw);
    const workerUrls = (env.AKASH_WORKER_URLS ?? "")
      .split(/[,\s]+/)
      .map((u) => u.trim())
      .filter(Boolean);

    let deploy: Record<string, unknown> | null = null;
    try {
      deploy = JSON.parse(await readFile(deployJsonPath, "utf8")) as Record<string, unknown>;
    } catch {
      deploy = null;
    }

    return NextResponse.json({
      ok: true,
      source: "akash-lease.env",
      owner: env.AKASH_OWNER ?? null,
      dseq: env.AKASH_DSEQ ?? null,
      provider: env.AKASH_PROVIDER ?? null,
      workerUrls,
      arenaQuery: workerUrls.length
        ? `?workers=${encodeURIComponent(workerUrls.join(","))}`
        : null,
      deploy,
    });
  } catch {
    return NextResponse.json(
      {
        ok: false,
        source: null,
        workerUrls: [],
        message: "No live lease state — run ./scripts/deploy-to-akash.sh deploy first",
      },
      { status: 404 }
    );
  }
}
