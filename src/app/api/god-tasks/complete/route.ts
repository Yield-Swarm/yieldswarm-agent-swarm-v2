import { ok, fail, parseBody } from "@/lib/http";
import fs from "node:fs/promises";
import path from "node:path";
import { z } from "zod";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  taskId: z.number().int().min(1).max(55),
  agentId: z.string().optional(),
  proof: z.string().optional(),
});

const LOG = path.join(process.cwd(), ".data", "god-task-completions.json");

/** POST /api/god-tasks/complete — God Task #48 SOL reward log */
export async function POST(request: Request) {
  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;

  const tasks = JSON.parse(
    await fs.readFile(path.join(process.cwd(), "config/god-tasks.json"), "utf8"),
  );
  const task = tasks.find((t: { id: number }) => t.id === body.data.taskId);
  if (!task) return fail("Unknown task id", 404);

  const record = {
    taskId: body.data.taskId,
    title: task.title,
    rewardSol: task.rewardSol,
    agentId: body.data.agentId ?? "swarm-orchestrator",
    completedAt: new Date().toISOString(),
    payoutStatus: "queued",
    chain: "solana-devnet",
  };

  await fs.mkdir(path.dirname(LOG), { recursive: true });
  let log: unknown[] = [];
  try {
    log = JSON.parse(await fs.readFile(LOG, "utf8"));
  } catch { /* empty */ }
  log.unshift(record);
  await fs.writeFile(LOG, JSON.stringify(log.slice(0, 500), null, 2));

  return ok({
    message: `God Task #${task.id} logged for SOL micro-payout`,
    record,
    note: "Configure SOLANA_RPC_URL + treasury wallet for on-chain payout",
  });
}

/** GET /api/god-tasks/complete — list completions */
export async function GET() {
  try {
    const log = JSON.parse(await fs.readFile(LOG, "utf8"));
    return ok({ completions: log });
  } catch {
    return ok({ completions: [] });
  }
}
