import { NextResponse } from "next/server";
import { kairoStore } from "@/lib/kairo/store";
import { routeToShard, shardToAgentId } from "@/lib/kairo/mandelbrot";
import type { SignedTelemetryEvent } from "@/lib/kairo/models";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST /api/kairo/telemetry
 * Ingest cryptographically signed driver telemetry into the Mandelbrot mesh.
 *
 * Body: SignedTelemetryEvent (without mandelbrotShard/ingestedAt — set server-side).
 */
export async function POST(request: Request) {
  let event: SignedTelemetryEvent;
  try {
    event = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  if (!event.driverId || !event.eventType || !event.signature || !event.signerAddress) {
    return NextResponse.json({ error: "Missing required fields" }, { status: 400 });
  }

  const result = await kairoStore.ingestTelemetry(event);
  if (!result.accepted) {
    return NextResponse.json({ accepted: false, reason: result.reason }, { status: 422 });
  }

  const shard = routeToShard(event);
  return NextResponse.json({
    accepted: true,
    eventId: event.id,
    mandelbrotShard: result.shard,
    agentId: shardToAgentId(shard),
    treeOfLife: {
      branch: shard.branch,
      tribe: shard.tribe,
      cronShard: shard.cronShard,
    },
  });
}

/**
 * GET /api/kairo/telemetry?driverId=...
 * Get contribution stats for a driver.
 */
export async function GET(request: Request) {
  const driverId = new URL(request.url).searchParams.get("driverId");
  if (!driverId) {
    return NextResponse.json({ error: "driverId query param required" }, { status: 400 });
  }

  const contribution = await kairoStore.getContribution(driverId);
  if (!contribution) {
    return NextResponse.json({ error: "Driver not found" }, { status: 404 });
  }

  return NextResponse.json({ contribution });
}
