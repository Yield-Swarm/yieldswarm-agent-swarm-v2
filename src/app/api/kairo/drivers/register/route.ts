import { NextResponse } from "next/server";
import { z } from "zod";
import { generateDriverIdentity, identityFromPrivateKey } from "@/lib/kairo/identity";
import { kairoStore } from "@/lib/kairo/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const RegisterSchema = z.object({
  /** If provided, re-register from existing device key instead of generating new */
  privateKey: z.string().regex(/^0x[0-9a-fA-F]{64}$/).optional(),
  metadata: z.record(z.unknown()).optional(),
});

/**
 * Register a Kairo driver and return their persistent cryptographic identity.
 * The private key is returned once — store it in the device secure enclave.
 */
export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Invalid JSON" }, { status: 400 });
  }

  const parsed = RegisterSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ ok: false, error: parsed.error.flatten() }, { status: 400 });
  }

  const generated = parsed.data.privateKey
    ? identityFromPrivateKey(parsed.data.privateKey, parsed.data.metadata)
    : generateDriverIdentity(parsed.data.metadata);

  await kairoStore.mutate((db) => {
    db.drivers[generated.identity.id] = generated.identity;
  });

  return NextResponse.json({
    ok: true,
    driver: {
      id: generated.identity.id,
      evmAddress: generated.identity.evmAddress,
      iotexAddress: generated.identity.iotexAddress,
      publicKey: generated.identity.publicKey,
      createdAt: generated.identity.createdAt,
    },
    /** Store securely on device — not persisted server-side */
    privateKey: generated.privateKey,
  });
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const driverId = searchParams.get("driverId");
  const evmAddress = searchParams.get("evmAddress");

  const db = await kairoStore.read();
  let driver = driverId ? db.drivers[driverId] : undefined;

  if (!driver && evmAddress) {
    driver = Object.values(db.drivers).find(
      (d) => d.evmAddress.toLowerCase() === evmAddress.toLowerCase(),
    );
  }

  if (!driver) {
    return NextResponse.json({ ok: false, error: "Driver not found" }, { status: 404 });
  }

  return NextResponse.json({
    ok: true,
    driver: {
      id: driver.id,
      evmAddress: driver.evmAddress,
      iotexAddress: driver.iotexAddress,
      publicKey: driver.publicKey,
      createdAt: driver.createdAt,
    },
  });
}
