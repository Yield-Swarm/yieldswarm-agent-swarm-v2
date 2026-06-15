import { NextResponse } from "next/server";
import { createDriverIdentity } from "@/lib/kairo/identity";
import { kairoStore } from "@/lib/kairo/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * POST /api/kairo/drivers/register
 * Register a new Kairo driver with a persistent cryptographic identity.
 *
 * Body: { displayName: string }
 * Returns: { identity, privateKey } — client must store privateKey securely.
 */
export async function POST(request: Request) {
  let body: { displayName?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON" }, { status: 400 });
  }

  const displayName = body.displayName?.trim();
  if (!displayName) {
    return NextResponse.json({ error: "displayName required" }, { status: 400 });
  }

  const drivers = await kairoStore.listDrivers();
  const { identity, privateKey } = createDriverIdentity(displayName, drivers.length);
  await kairoStore.registerDriver(identity);

  return NextResponse.json({
    identity: {
      id: identity.id,
      displayName: identity.displayName,
      evmAddress: identity.evmAddress,
      iotexAddress: identity.iotexAddress,
      publicKey: identity.publicKey,
      swarmShardId: identity.swarmShardId,
      status: identity.status,
      createdAt: identity.createdAt,
    },
    privateKey,
    warning: "Store privateKey securely on the device. It cannot be recovered.",
  });
}

/**
 * GET /api/kairo/drivers/register
 * List registered drivers (public fields only).
 */
export async function GET() {
  const drivers = await kairoStore.listDrivers();
  return NextResponse.json({
    drivers: drivers.map((d) => ({
      id: d.id,
      displayName: d.displayName,
      evmAddress: d.evmAddress,
      iotexAddress: d.iotexAddress,
      swarmShardId: d.swarmShardId,
      status: d.status,
      lastActiveAt: d.lastActiveAt,
    })),
  });
}
