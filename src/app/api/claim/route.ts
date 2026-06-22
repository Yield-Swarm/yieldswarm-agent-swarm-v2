import { NextResponse } from "next/server";
import { createHash } from "node:crypto";
import { checkEmissionRateLimit } from "@/lib/server/rateLimiter";
import { signClaimPayload } from "@/lib/server/signer";
import { calculatePoEEmission } from "@/lib/game/engine";
import { fetchPlayerLastSaveTimestamp, resolveDeltaTime } from "@/lib/ton/playerState";
import { ClaimRequestSchema } from "@/types/game";
import { fail, parseBody } from "@/lib/http";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function actionHash(action: Record<string, unknown>): string {
  return createHash("sha256").update(JSON.stringify(action)).digest("hex").slice(0, 64);
}

/**
 * POST /api/claim — server-authoritative PoE emission claim.
 * deltaTime is derived from on-chain/indexed lastSaveTimestamp (never client clock).
 */
export async function POST(request: Request) {
  try {
    const parsed = await parseBody(request, ClaimRequestSchema);
    if ("response" in parsed) return parsed.response;

    const { walletAddress, action, nonce } = parsed.data;

    const rateLimit = await checkEmissionRateLimit(walletAddress);
    if (!rateLimit.allowed) {
      return NextResponse.json(
        {
          ok: false,
          error: "Rate limit exceeded. Too many actions submitted.",
          remainingTokens: rateLimit.remainingTokens,
        },
        { status: 429 },
      );
    }

    const { lastSaveTimestamp, source } =
      await fetchPlayerLastSaveTimestamp(walletAddress);

    const currentUnixTime = Math.floor(Date.now() / 1000);
    const calculatedDeltaTime = resolveDeltaTime(lastSaveTimestamp, currentUnixTime);

    const validatedAction = {
      ...action,
      deltaTime: calculatedDeltaTime,
    };

    const emission = calculatePoEEmission(validatedAction);
    if (emission <= 0n) {
      return fail("Action generated zero token emission.", 400);
    }

    const hash = actionHash(validatedAction);
    const signature = signClaimPayload({
      recipient: walletAddress,
      amount: emission.toString(),
      actionHash: hash,
      nonce,
      timestamp: currentUnixTime,
    });

    return NextResponse.json({
      ok: true,
      success: true,
      data: {
        emission: emission.toString(),
        deltaTime: calculatedDeltaTime,
        stateSource: source,
        remainingTokens: rateLimit.remainingTokens,
      },
      contractMessage: {
        amount: emission.toString(),
        actionHash: hash,
        serverSignature: signature,
        nonce,
        timestamp: currentUnixTime,
      },
    });
  } catch (error) {
    console.error("[Authoritative Claim Error]:", error);
    return fail(
      error instanceof Error ? error.message : "Internal execution failure.",
      400,
    );
  }
}
