import { z } from "zod";
import { parseBody, ok, fail } from "@/lib/http";
import { railConfigured } from "@/lib/config/env";
import { createPaymentRequest } from "@/lib/payments/wise";
import { logSale } from "@/lib/revenue/store";
import { reference } from "@/lib/ids";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  amountUsd: z.number().positive().max(100_000),
  product: z.string().min(1).max(120),
  rails: z.array(z.enum(["wise", "web3", "stripe"])).optional(),
});

/**
 * POST /api/revenue/z15-test
 * $5 (or bundle) payment rail test — Wise link + sale log + on-chain reference.
 */
export async function POST(request: Request) {
  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;

  const { amountUsd, product, rails } = body.data;
  const ref = reference("z15");
  const sale = await logSale({
    product,
    amountUsd,
    reference: ref,
    rails: rails ?? ["wise", "web3"],
    source: "z15-test",
  });

  let wiseLink: string | undefined;
  let wiseKind = "unconfigured";

  if (railConfigured("wise")) {
    try {
      const result = await createPaymentRequest({
        amount: String(amountUsd),
        currency: "USD",
        reference: ref,
        description: `YieldSwarm ${product}`,
      });
      wiseKind = result.kind;
      wiseLink = result.link;
    } catch (err) {
      return ok({
        ok: true,
        message: `Sale logged ($${amountUsd}). Wise unavailable: ${(err as Error).message}`,
        reference: ref,
        sale,
        wiseLink: undefined,
      });
    }
  }

  const web3Payload = {
    chain: "sepolia",
    amountUsd,
    reference: ref,
    verifyUrl: `/api/deposits/web3/verify?reference=${encodeURIComponent(ref)}`,
  };

  return ok({
    ok: true,
    message: `Payment test initiated — $${amountUsd} ${product}`,
    reference: ref,
    sale,
    wiseLink,
    wiseKind,
    web3: web3Payload,
    totalRevenueUsd: sale.amountUsd,
  });
}
