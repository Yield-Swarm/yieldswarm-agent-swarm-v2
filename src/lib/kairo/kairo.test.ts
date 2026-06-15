import { describe, expect, it } from "vitest";
import { computeTripFees, CUSTOMER_FEE_RATE, DRIVER_PAY_MULTIPLIER } from "@/lib/kairo/fees";
import { evmToIotexAddress, generateDriverIdentity } from "@/lib/kairo/identity";
import { canonicalizePayload, signTelemetry, verifyTelemetrySignature } from "@/lib/kairo/signing";
import { routeTelemetry } from "@/lib/kairo/mandelbrot";

describe("kairo fees", () => {
  it("applies 1% customer fee and 2x driver pay", () => {
    const fees = computeTripFees("100.00");
    expect(parseFloat(fees.customerFee)).toBeCloseTo(100 * CUSTOMER_FEE_RATE);
    expect(parseFloat(fees.driverPay)).toBeGreaterThan(parseFloat(fees.driverBasePay));
    expect(DRIVER_PAY_MULTIPLIER).toBe(2);
  });
});

describe("kairo identity", () => {
  it("derives IoTeX address from EVM key", () => {
    const { identity } = generateDriverIdentity();
    expect(identity.evmAddress).toMatch(/^0x[0-9a-fA-F]{40}$/);
    expect(identity.iotexAddress).toMatch(/^io1/);
    expect(evmToIotexAddress(identity.evmAddress)).toBe(identity.iotexAddress);
  });
});

describe("kairo signing", () => {
  it("signs and verifies telemetry", () => {
    const { identity, privateKey } = generateDriverIdentity();
    const payload = {
      timestamp: new Date().toISOString(),
      latitude: 39.7392,
      longitude: -104.9903,
      speedMph: 35,
      headingDeg: 90,
      distanceMiles: 1.2,
    };
    const sig = signTelemetry(privateKey, payload);
    expect(verifyTelemetrySignature(payload, sig, identity.evmAddress)).toBe(true);
    expect(canonicalizePayload(payload)).toContain('"latitude"');
  });
});

describe("mandelbrot router", () => {
  it("routes telemetry to a shard", () => {
    const route = routeTelemetry("driver-abc", { speedMph: 40, distanceMiles: 5 });
    expect(route.mandelbrotShard).toBeGreaterThanOrEqual(0);
    expect(route.mandelbrotShard).toBeLessThan(120);
    expect(route.treeOfLifeNode).toBeTruthy();
  });
});
