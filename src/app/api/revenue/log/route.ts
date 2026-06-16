import { z } from "zod";
import { parseBody, ok, fail } from "@/lib/http";
import { logSale, listRecentSales } from "@/lib/revenue/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const postSchema = z.object({
  product: z.string().min(1).max(120),
  amountUsd: z.number().positive(),
  tier: z.string().optional(),
  source: z.string().optional(),
  rails: z.array(z.string()).optional(),
});

/** GET /api/revenue/log — recent sales (Neon or local JSON) */
export async function GET(request: Request) {
  const limit = Number(new URL(request.url).searchParams.get("limit") || "20");
  const sales = await listRecentSales(Math.min(limit, 100));
  return ok({ sales });
}

/** POST /api/revenue/log — record a sale */
export async function POST(request: Request) {
  const body = await parseBody(request, postSchema);
  if ("response" in body) return body.response;
  const record = await logSale(body.data);
  return ok({ sale: record });
}
