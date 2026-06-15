import { z } from "zod";
import { spawnSync } from "child_process";
import { ok, fail, parseBody } from "@/lib/http";
import { appendTelemetry, getDriver } from "@/lib/kairo/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  driverId: z.string().min(4),
  evmAddress: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  samples: z
    .array(
      z.object({
        payload: z.record(z.unknown()),
        signature: z.string(),
      }),
    )
    .min(1)
    .max(100),
});

export async function POST(request: Request) {
  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;

  const { driverId, evmAddress, samples } = body.data;
  const driver = getDriver(driverId);
  if (!driver) return fail("Driver not found", 404);
  if (driver.evmAddress.toLowerCase() !== evmAddress.toLowerCase()) {
    return fail("EVM address mismatch", 403);
  }

  const script = `
import json, sys
sys.path.insert(0, ".")
from kairo.pipeline.mandelbrot import route_to_tree
signed = json.loads(sys.argv[1])
driver_id = sys.argv[2]
print(json.dumps(route_to_tree(driver_id, signed)))
`;
  const result = spawnSync("python3", ["-c", script, JSON.stringify(samples), driverId], {
    cwd: process.cwd(),
    encoding: "utf-8",
  });
  if (result.status !== 0) {
    return fail(result.stderr || "Pipeline routing failed", 500);
  }

  const routed = JSON.parse(result.stdout.trim()) as Array<{
    tree_node: string;
    reward_weight: number;
    telemetry: Record<string, unknown>;
  }>;

  const stored = appendTelemetry(
    driverId,
    routed.map((r) => ({
      treeNode: r.tree_node,
      rewardWeight: r.reward_weight,
      payload: r.telemetry,
    })),
  );

  return ok({
    ingested: stored.length,
    nodes: [...new Set(stored.map((t) => t.treeNode))],
    totalRewardWeight: stored.reduce((s, t) => s + t.rewardWeight, 0),
  });
}
