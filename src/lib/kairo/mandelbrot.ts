/**
 * Routes signed Kairo telemetry into the YieldSwarm Mandelbrot / Tree of Life
 * sharding architecture (10,080 agents across 120 cron shards).
 */

import { SignedTelemetry, ContributionRecord } from "@/lib/kairo/models";
import { driverShardIndex } from "@/lib/kairo/identity";
import { nowIso, uuid } from "@/lib/ids";

export const AGENT_COUNT_TOTAL = 10_080;
export const CRON_SHARD_COUNT = 120;
export const AGENTS_PER_SHARD = 84;

/** Tree of Life sephirot nodes used for telemetry classification */
export const TREE_OF_LIFE_NODES = [
  "kether",
  "chokmah",
  "binah",
  "chesed",
  "geburah",
  "tiphereth",
  "netzach",
  "hod",
  "yesod",
  "malkuth",
] as const;

export type TreeOfLifeNode = (typeof TREE_OF_LIFE_NODES)[number];

export interface MandelbrotRoute {
  mandelbrotShard: number;
  treeOfLifeNode: TreeOfLifeNode;
  agentRangeStart: number;
  agentRangeEnd: number;
  cronShardId: number;
}

/** Map geographic + kinematic data to a Tree of Life node for routing context. */
export function classifyTreeNode(payload: SignedTelemetry["payload"]): TreeOfLifeNode {
  const speed = payload.speedMph ?? 0;
  const distance = payload.distanceMiles ?? 0;

  if (speed < 1) return "malkuth";
  if (speed < 15) return "yesod";
  if (speed < 35) return "hod";
  if (speed < 55) return "netzach";
  if (distance > 50) return "chokmah";
  if (distance > 20) return "binah";
  return "tiphereth";
}

/** Compute Mandelbrot shard + agent range for a driver telemetry record. */
export function routeTelemetry(
  driverId: string,
  payload: SignedTelemetry["payload"],
): MandelbrotRoute {
  const cronShardId = driverShardIndex(driverId, CRON_SHARD_COUNT);
  const treeOfLifeNode = classifyTreeNode(payload);

  // Mandelbrot iteration depth derived from shard + speed (bounded 0–119)
  const mandelbrotShard = (cronShardId + Math.floor(payload.speedMph)) % CRON_SHARD_COUNT;

  const agentRangeStart = cronShardId * AGENTS_PER_SHARD;
  const agentRangeEnd = agentRangeStart + AGENTS_PER_SHARD - 1;

  return {
    mandelbrotShard,
    treeOfLifeNode,
    agentRangeStart,
    agentRangeEnd,
    cronShardId,
  };
}

/** Apply routing metadata to a signed telemetry record (mutates copy). */
export function enrichWithRouting(record: SignedTelemetry): SignedTelemetry {
  const route = routeTelemetry(record.driverId, record.payload);
  return {
    ...record,
    mandelbrotShard: route.mandelbrotShard,
    treeOfLifeNode: route.treeOfLifeNode,
  };
}

/** Estimate DePIN reward units from verified telemetry volume. */
export function estimateDepinRewards(
  telemetryCount: number,
  totalDistanceMiles: number,
): string {
  const base = telemetryCount * 0.001 + totalDistanceMiles * 0.05;
  return base.toFixed(4);
}

/** Upsert a contribution record for a driver over the current period. */
export function upsertContribution(
  existing: ContributionRecord | undefined,
  driverId: string,
  delta: { telemetryCount: number; distanceMiles: number; appRevenue?: string },
): ContributionRecord {
  const now = nowIso();
  const periodStart = existing?.periodStart ?? now;
  const telemetryCount = (existing?.telemetryCount ?? 0) + delta.telemetryCount;
  const totalDistanceMiles =
    parseFloat(existing?.totalDistanceMiles?.toString() ?? "0") + delta.distanceMiles;

  const appRevenueShare = (
    parseFloat(existing?.appRevenueShare ?? "0") + parseFloat(delta.appRevenue ?? "0")
  ).toFixed(2);

  return {
    id: existing?.id ?? uuid(),
    driverId,
    telemetryCount,
    totalDistanceMiles,
    estimatedDepinRewards: estimateDepinRewards(telemetryCount, totalDistanceMiles),
    appRevenueShare,
    currency: "USD",
    periodStart,
    periodEnd: now,
    updatedAt: now,
  };
}
