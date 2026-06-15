import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { railConfigured } from "@/lib/config/env";
import { createTransaction, updateTransactionStatus } from "@/lib/ledger";
import { createPaymentRequest } from "@/lib/payments/wise";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  amount: z.string().regex(/^\d+(\.\d+)?$/),
  currency: z.string().length(3).default("USD"),
  description: z.string().max(120).optional(),
});

/** Inbound fiat deposit via Wise (payment request / receiving details). */
export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;
  if (!railConfigured("wise")) return fail("Wise is not configured", 503);

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const { amount, currency, description } = body.data;

  const tx = await createTransaction({
    userId: auth.user.id,
    direction: "deposit",
    rail: "wise",
    amount,
    currency,
    status: "pending",
  });

  try {
    const result = await createPaymentRequest({
      amount,
      currency,
      reference: tx.reference,
      description,
    });
    await updateTransactionStatus(tx.id, "pending", {
      externalId: result.id,
      metadata: { kind: result.kind, link: result.link },
    });
    return ok({ transaction: tx, paymentRequest: result });
  } catch (err) {
    await updateTransactionStatus(tx.id, "failed", {
      metadata: { error: (err as Error).message },
    });
    return fail((err as Error).message || "Wise deposit failed", 502);
  }
}
