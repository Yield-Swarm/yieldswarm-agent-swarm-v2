import { spawnSync } from "child_process";
import { ok, fail } from "@/lib/http";
import { registerDriver } from "@/lib/kairo/store";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Register a new Kairo driver with persistent IoTeX + EVM identity. */
export async function POST() {
  const script = `
import json, sys
sys.path.insert(0, ".")
from kairo.identity.wallet import create_driver_identity
identity, _ = create_driver_identity()
print(json.dumps(identity.to_dict()))
`;
  const result = spawnSync("python3", ["-c", script], { cwd: process.cwd(), encoding: "utf-8" });
  if (result.status !== 0) {
    return fail(result.stderr || "Failed to generate driver identity", 500);
  }

  const identity = JSON.parse(result.stdout.trim()) as {
    driver_id: string;
    evm_address: string;
    iotex_address: string;
    public_key_fingerprint: string;
  };

  const record = registerDriver({
    driverId: identity.driver_id,
    evmAddress: identity.evm_address,
    iotexAddress: identity.iotex_address,
    publicKeyFingerprint: identity.public_key_fingerprint,
    registeredAt: new Date().toISOString(),
    telemetryCount: 0,
    totalRewardWeight: 0,
    totalDistanceM: 0,
    appEarningsUsd: "0.00",
    depinRewardsUsd: "0.00",
  });

  return ok({
    driver: record,
    note: "Store the device-generated private key on the driver handset — it is never sent to the server.",
  });
}
