import { z } from "zod";
import { ok, fail, parseBody } from "@/lib/http";
import { settleDriverTrip } from "@/lib/payments/fees";
import { addDriverEarnings, getDriver } from "@/lib/kairo/store";
import { railConfigured } from "@/lib/config/env";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const schema = z.object({
  driverId: z.string().min(4),
  baseFare: z.string().regex(/^\d+(\.\d{1,2})?$/),
  currency: z.string().length(3).optional(),
  instantCashout: z.boolean().optional(),
  depinRewardWeight: z.number().min(0).max(10).optional(),
  /** Square/Wise rail for instant cashout when configured. */
  payoutRail: z.enum(["square", "wise", "web3"]).optional(),
});

/** Settle a trip — driver 2× pay with optional instant cashout. */
export async function POST(request: Request) {
  const body = await parseBody(request, schema);
  if ("response" in body) return body.response;

  const driver = getDriver(body.data.driverId);
  if (!driver) return fail("Driver not found", 404);

  const settlement = settleDriverTrip(body.data);
  addDriverEarnings(
    body.data.driverId,
    settlement.breakdown.appRevenue,
    settlement.breakdown.depinRewards,
  );

  const rail = body.data.payoutRail ?? "wise";
  const payoutAvailable = railConfigured(rail as "square" | "wise" | "web3");

  return ok({
    settlement,
    payout: {
      rail,
      instantCashout: settlement.instantCashout,
      amount: settlement.driverNetPay,
      currency: settlement.currency,
      configured: payoutAvailable,
      note: payoutAvailable
        ? "Use /api/withdrawals/bank or /api/withdrawals/web3 to execute payout."
        : `${rail} rail not configured — settlement recorded, payout pending.`,
    },
  });
}
