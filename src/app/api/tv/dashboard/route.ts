import { ok } from "@/lib/http";
import { buildTvDashboard } from "@/lib/tv/aggregate";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

/** GET /api/tv/dashboard — aggregated TV display payload */
export async function GET() {
  const data = await buildTvDashboard();
  return ok(data);
}
