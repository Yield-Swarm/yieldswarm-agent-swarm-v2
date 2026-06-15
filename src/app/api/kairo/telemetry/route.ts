import { NextResponse } from "next/server";
import { z } from "zod";
import { kairoStore } from "@/lib/kairo/store";
import {
  buildSignedTelemetry,
  canonicalizePayload,
  verifyTelemetrySignature,
} from "@/lib/kairo/signing";
import { enrichWithRouting, upsertContribution } from "@/lib/kairo/mandelbrot";
import { TelemetryPayload } from "@/lib/kairo/models";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const TelemetrySchema = z.object({
  driverId: z.string().uuid(),
  signature: z.string().regex(/^0x[0-9a-fA-F]+$/),
  payload: z.object({
    timestamp: z.string(),
    latitude: z.number(),
    longitude: z.number(),
    speedMph: z.number().min(0),
    headingDeg: z.number(),
    distanceMiles: z.number().min(0),
    sessionId: z.string().optional(),
    deviceId: z.string().optional(),
  }),
});

/**
 * Ingest cryptographically signed driving telemetry from a Kairo driver node.
 * Verified records are routed into the Mandelbrot / Tree of Life architecture.
 */
export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const parsed = TelemetrySchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: parsed.error.flatten() }, { status: 400 });
  }

  const { driverId, signature, payload } = parsed.data;
  const db = await kairoStore.read();
  const driver = db.drivers[driverId];

  if (!driver) {
    return NextResponse.json({ ok: false, error: "Unknown driver" }, { status: 404 });
  }

  const verified = verifyTelemetrySignature(
    payload as TelemetryPayload,
    signature,
    driver.evmAddress,
  );

  if (!verified) {
    return NextResponse.json({ ok: false, error: "Invalid signature" }, { status: 401 });
  }

  let record = buildSignedTelemetry(driverId, driver.evmAddress, payload as TelemetryPayload, signature, true);
  record = enrichWithRouting(record);

  const contribution = await kairoStore.mutate((store) => {
    store.telemetry[record.id] = record;
    const existing = Object.values(store.contributions).find((c) => c.driverId === driverId);
    const updated = upsertContribution(existing, driverId, {
      telemetryCount: 1,
      distanceMiles: payload.distanceMiles,
    });
    store.contributions[updated.id] = updated;
    return updated;
  });

  return NextResponse.json({
    ok: true,
    telemetryId: record.id,
    verified: true,
    routing: {
      mandelbrotShard: record.mandelbrotShard,
      treeOfLifeNode: record.treeOfLifeNode,
    },
    contribution: {
      telemetryCount: contribution.telemetryCount,
      totalDistanceMiles: contribution.totalDistanceMiles,
      estimatedDepinRewards: contribution.estimatedDepinRewards,
    },
    payloadHash: canonicalizePayload(payload as TelemetryPayload),
  });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const driverId = searchParams.get("driverId");
  const limit = Math.min(parseInt(searchParams.get("limit") ?? "50", 10), 200);

  const db = await kairoStore.read();
  let records = Object.values(db.telemetry);
  if (driverId) records = records.filter((r) => r.driverId === driverId);
  records.sort((a, b) => b.receivedAt.localeCompare(a.receivedAt));

  return NextResponse.json({
    ok: true,
    count: records.length,
    telemetry: records.slice(0, limit),
  });
}
