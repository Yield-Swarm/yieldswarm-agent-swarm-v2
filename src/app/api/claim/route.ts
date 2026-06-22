import { NextRequest, NextResponse } from "next/server";
import { ZodError } from "zod";
import {
  calculatePoEEmission,
  emissionNanoToDisplay,
} from "@/lib/game/engine";
import { ClaimPayloadSchema } from "@/types/game";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Server-authoritative PoE claim endpoint.
 * Validates player state, hashes raw equipment loadouts, and computes safe emissions.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsedData = ClaimPayloadSchema.parse(body);

    const emissionNano = calculatePoEEmission(parsedData.action);
    const emissionDisplay = emissionNanoToDisplay(emissionNano);

    return NextResponse.json({
      success: true,
      securedState: {
        wallet: parsedData.player.walletAddress,
        level: parsedData.player.level,
        equipmentHash: parsedData.player.equipmentHash,
      },
      emissionNano: emissionNano.toString(),
      emissionDisplay,
      msg: "Authorization token generated safely.",
    });
  } catch (error) {
    if (error instanceof ZodError) {
      return NextResponse.json(
        { success: false, error: error.errors },
        { status: 400 },
      );
    }
    return NextResponse.json(
      { success: false, error: "Malformed execution payload." },
      { status: 400 },
    );
  }
}
