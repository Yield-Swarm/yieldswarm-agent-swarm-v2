import { z } from "zod";
import { requireUser, parseBody, ok, fail } from "@/lib/http";
import { railConfigured } from "@/lib/config/env";
import { reserveWithdrawal, completeWithdrawal, refundWithdrawal } from "@/lib/ledger";
import { createBankPayout } from "@/lib/payments/wise";
import { uuid } from "@/lib/ids";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  amount: z.string().regex(/^\d+(\.\d+)?$/),
  sourceCurrency: z.string().length(3).default("USD"),
  targetCurrency: z.string().length(3).default("USD"),
  recipient: z.object({
    currency: z.string().length(3),
    type: z.string().min(2), // iban | aba | sort_code | email ...
    accountHolderName: z.string().min(2),
    legalType: z.enum(["PRIVATE", "BUSINESS"]).optional(),
    details: z.record(z.unknown()),
  }),
  reference: z.string().max(35).optional(),
});

/** Off-ramp: withdraw fiat to a bank account via Wise. */
export async function POST(request: Request) {
  const auth = await requireUser();
  if ("response" in auth) return auth.response;
  if (!railConfigured("wise")) return fail("Wise is not configured", 503);

  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;
  const data = body.data;

  const reserved = await reserveWithdrawal({
    userId: auth.user.id,
    rail: "wise",
    amount: data.amount,
    currency: data.sourceCurrency,
    metadata: { targetCurrency: data.targetCurrency, recipientType: data.recipient.type },
  });
  if ("error" in reserved) return fail(reserved.error, 400);
  const { tx } = reserved;

  try {
    const payout = await createBankPayout({
      amount: data.amount,
      sourceCurrency: data.sourceCurrency,
      targetCurrency: data.targetCurrency,
      recipient: data.recipient,
      customerTransactionId: uuid(),
      reference: data.reference ?? `YS-${tx.reference}`,
    });
    const completed = await completeWithdrawal(tx.id, {
      externalId: String(payout.transferId),
      metadata: { wiseStatus: payout.status, quoteId: payout.quoteId, funded: payout.funded },
    });
    return ok({ transaction: completed, payout });
  } catch (err) {
    await refundWithdrawal(tx.id, (err as Error).message);
    return fail((err as Error).message || "Wise payout failed", 502);
  }
}
