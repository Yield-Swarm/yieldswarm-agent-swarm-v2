import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { railConfigured, serverEnv } from "@/lib/config/env";
import { createTransaction, updateTransactionStatus } from "@/lib/ledger";
import { createCardCheckoutLink, createDirectPayment } from "@/lib/payments/square";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.discriminatedUnion("mode", [
  z.object({
    mode: z.literal("checkout"),
    amount: z.string().regex(/^\d+(\.\d+)?$/),
    currency: z.string().length(3).default("USD"),
    description: z.string().max(120).optional(),
  }),
  z.object({
    mode: z.literal("payment"),
    amount: z.string().regex(/^\d+(\.\d+)?$/),
    currency: z.string().length(3).default("USD"),
    sourceId: z.string().min(4),
    verificationToken: z.string().optional(),
    method: z.enum(["CARD", "ACH"]).optional(),
    buyerEmail: z.string().email().optional(),
  }),
]);

export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;
  if (!railConfigured("square")) return fail("Square is not configured", 503);

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const data = body.data;

  // Create the pending deposit first so we have a reference to correlate later.
  const tx = await createTransaction({
    userId: auth.user.id,
    direction: "deposit",
    rail: "square",
    amount: data.amount,
    currency: data.currency,
    status: "pending",
    metadata: { mode: data.mode },
  });

  try {
    if (data.mode === "checkout") {
      const link = await createCardCheckoutLink({
        amount: data.amount,
        currency: data.currency,
        reference: tx.reference,
        description: data.description,
        redirectUrl: `${serverEnv.appUrl}/payments?deposit=${tx.reference}`,
        buyerEmail: auth.user.email.endsWith("@anon.yieldswarm.local")
          ? undefined
          : auth.user.email,
      });
      await updateTransactionStatus(tx.id, "pending", {
        externalId: link.paymentLinkId,
        metadata: { orderId: link.orderId, checkoutUrl: link.url },
      });
      return ok({ transaction: tx, checkoutUrl: link.url, paymentLinkId: link.paymentLinkId });
    }

    // Direct payment (card token or ACH bank token from the Web Payments SDK).
    const payment = await createDirectPayment({
      sourceId: data.sourceId,
      verificationToken: data.verificationToken,
      amount: data.amount,
      currency: data.currency,
      reference: tx.reference,
      method: data.method,
      buyerEmail: data.buyerEmail,
    });

    // Card completes synchronously; ACH stays pending until the webhook settles.
    const settled = payment.status === "COMPLETED";
    await updateTransactionStatus(tx.id, settled ? "completed" : "processing", {
      externalId: payment.paymentId,
      metadata: { squareStatus: payment.status, orderId: payment.orderId },
    });

    return ok({
      transaction: { ...tx, status: settled ? "completed" : "processing" },
      payment,
    });
  } catch (err) {
    await updateTransactionStatus(tx.id, "failed", {
      metadata: { error: (err as Error).message },
    });
    return fail((err as Error).message || "Square deposit failed", 502);
  }
}
