import { NextRequest, NextResponse } from "next/server";
import { ZodError } from "zod";
import { runSettlementPipeline } from "@/lib/game/pipeline";
import { getSettlementPublicKeyHex } from "@/lib/game/signing";
import { ClaimRequestSchema } from "@/types/game";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * TON MMORPG settlement endpoint (Layer 2 → Layer 3 handoff).
 *
 * Flow: rate limit → on-chain Δt → PoE bigint math → Ed25519 sign → BOC for TonConnect.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const request = ClaimRequestSchema.parse(body);
    const result = await runSettlementPipeline(request);

    if (!result.success) {
      const status = result.code === "RATE_LIMITED" ? 429 : 400;
      return NextResponse.json(result, {
        status,
        headers: result.retryAfterSec
          ? { "Retry-After": String(result.retryAfterSec) }
          : undefined,
      });
    }

    return NextResponse.json({
      ...result,
      serverPublicKey: getSettlementPublicKeyHex(),
    });
  } catch (error) {
    if (error instanceof ZodError) {
      return NextResponse.json(
        { success: false, code: "INVALID_STATE", error: error.errors },
        { status: 400 },
      );
    }
    return NextResponse.json(
      { success: false, code: "INVALID_STATE", error: "Malformed execution payload." },
      { status: 400 },
    );
  }
}
