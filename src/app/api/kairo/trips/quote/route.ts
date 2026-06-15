import { z } from "zod";
import { ok, parseBody } from "@/lib/http";
import { quoteTrip } from "@/lib/payments/fees";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  baseFare: z.string().regex(/^\d+(\.\d{1,2})?$/),
  currency: z.string().length(3).optional(),
});

/** Customer trip quote with 1% flat platform fee. */
export async function POST(request: Request) {
  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  return ok(quoteTrip(body.data));
}
