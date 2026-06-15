/**
 * In-memory store for Kairo drivers, telemetry, and contributions.
 * Replace with Postgres/Neon in production.
 */

import type {
  DriverIdentity,
  SignedTelemetryEvent,
  DriverContribution,
  DriverEarnings,
  KairoRide,
} from "./models";
import { estimateRewardPoints, routeToShard } from "./mandelbrot";
import { verifyTelemetrySignature } from "./signing";
import { nowIso } from "@/lib/ids";

interface KairoDB {
  drivers: Record<string, DriverIdentity>;
  events: Record<string, SignedTelemetryEvent>;
  contributions: Record<string, DriverContribution>;
  rides: Record<string, KairoRide>;
  earnings: Record<string, DriverEarnings[]>;
}

let db: KairoDB = {
  drivers: {},
  events: {},
  contributions: {},
  rides: {},
  earnings: {},
};

export const kairoStore = {
  async read(): Promise<KairoDB> {
    return db;
  },

  async mutate<T>(fn: (db: KairoDB) => T): Promise<T> {
    return fn(db);
  },

  async registerDriver(identity: DriverIdentity): Promise<DriverIdentity> {
    return this.mutate((d) => {
      d.drivers[identity.id] = identity;
      d.contributions[identity.id] = {
        driverId: identity.id,
        totalEvents: 0,
        signedEvents: 0,
        invalidSignatures: 0,
        totalKm: 0,
        mandelbrotShards: [],
        estimatedRewardPoints: 0,
      };
      return identity;
    });
  },

  async getDriver(id: string): Promise<DriverIdentity | null> {
    const d = await this.read();
    return d.drivers[id] ?? null;
  },

  async ingestTelemetry(event: SignedTelemetryEvent): Promise<{
    accepted: boolean;
    reason?: string;
    shard?: number;
  }> {
    const valid = await verifyTelemetrySignature(event);
    if (!valid) {
      await this.mutate((d) => {
        const c = d.contributions[event.driverId];
        if (c) c.invalidSignatures++;
      });
      return { accepted: false, reason: "invalid_signature" };
    }

    const driver = await this.getDriver(event.driverId);
    if (!driver) return { accepted: false, reason: "unknown_driver" };
    if (driver.evmAddress.toLowerCase() !== event.signerAddress.toLowerCase()) {
      return { accepted: false, reason: "signer_mismatch" };
    }

    const shard = routeToShard(event);
    event.mandelbrotShard = shard.globalIndex;
    event.ingestedAt = nowIso();

    await this.mutate((d) => {
      d.events[event.id] = event;
      const c = d.contributions[event.driverId];
      if (!c) return;
      c.totalEvents++;
      c.signedEvents++;
      c.lastEventAt = event.timestamp;

      const km = Number(event.payload.distance_km ?? event.payload.km ?? 0);
      if (km > 0) c.totalKm += km;

      if (!c.mandelbrotShards.includes(shard.globalIndex)) {
        c.mandelbrotShards.push(shard.globalIndex);
      }
      c.estimatedRewardPoints = estimateRewardPoints(
        c.signedEvents,
        c.totalKm,
        c.mandelbrotShards.length,
      );

      const drv = d.drivers[event.driverId];
      if (drv) drv.lastActiveAt = nowIso();
    });

    return { accepted: true, shard: shard.globalIndex };
  },

  async getContribution(driverId: string): Promise<DriverContribution | null> {
    const d = await this.read();
    return d.contributions[driverId] ?? null;
  },

  async listDrivers(): Promise<DriverIdentity[]> {
    const d = await this.read();
    return Object.values(d.drivers);
  },
};
