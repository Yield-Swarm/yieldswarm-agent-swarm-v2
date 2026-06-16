import { ok, fail } from "@/lib/http";
import { getRevenueMetrics } from "@/lib/revenue/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** GET /api/revenue/metrics — live hero metrics for jacuzzi-Helix site */
export async function GET() {
  const metrics = await getRevenueMetrics();
  return ok(metrics);
}
