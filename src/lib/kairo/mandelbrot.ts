/**
 * Mandelbrot / Tree of Life data routing for Kairo telemetry.
 *
 * Maps signed telemetry events into fractal shards of the YieldSwarm mesh.
 * Each event's coordinates (lat/lng or synthetic hash) determine which of the
 * 10,080 agent shards receives the data for mutation and reward attribution.
 *
 * The Tree of Life has 7 branches × 12 tribes × 120 cron shards = 10,080 nodes.
 */

import type { SignedTelemetryEvent } from "./models";

const TREE_BRANCHES = 7;
const TREE_TRIBES = 12;
const CRON_SHARDS = 120;
export const TOTAL_MESH_NODES = TREE_BRANCHES * TREE_TRIBES * CRON_SHARDS; // 10,080

export interface MandelbrotCoordinate {
  real: number;
  imaginary: number;
  iteration: number;
  escaped: boolean;
}

export interface TreeOfLifeShard {
  branch: number;   // 0..6
  tribe: number;    // 0..11
  cronShard: number; // 0..119
  agentIndex: number; // 0..83 within shard
  globalIndex: number; // 0..10079
}

/** Compute Mandelbrot iteration count for a lat/lng pair. */
export function mandelbrotIteration(lat: number, lng: number, maxIter = 64): MandelbrotCoordinate {
  // Map lat/lng to complex plane region (-2.5, 1.0) × (-1.5, 1.5)
  const real = (lng + 180) / 360 * 3.5 - 2.5;
  const imaginary = (lat + 90) / 180 * 3.0 - 1.5;

  let zr = 0;
  let zi = 0;
  let iteration = 0;
  let escaped = false;

  while (iteration < maxIter) {
    const zr2 = zr * zr;
    const zi2 = zi * zi;
    if (zr2 + zi2 > 4) {
      escaped = true;
      break;
    }
    const newZr = zr2 - zi2 + real;
    zi = 2 * zr * zi + imaginary;
    zr = newZr;
    iteration++;
  }

  return { real, imaginary, iteration, escaped };
}

/** Route a telemetry event to a Tree of Life shard. */
export function routeToShard(event: SignedTelemetryEvent): TreeOfLifeShard {
  const lat = Number(event.payload.lat ?? event.payload.latitude ?? 0);
  const lng = Number(event.payload.lng ?? event.payload.longitude ?? 0);

  let coord: MandelbrotCoordinate;
  if (lat !== 0 || lng !== 0) {
    coord = mandelbrotIteration(lat, lng);
  } else {
    // Fallback: hash driver ID + timestamp for synthetic routing.
    const hash = simpleHash(`${event.driverId}:${event.timestamp}`);
    coord = {
      real: (hash % 1000) / 1000,
      imaginary: ((hash >> 10) % 1000) / 1000,
      iteration: hash % 64,
      escaped: (hash & 1) === 1,
    };
  }

  const branch = coord.iteration % TREE_BRANCHES;
  const tribe = Math.floor(coord.real * 100) % TREE_TRIBES;
  const cronShard = Math.floor(coord.imaginary * 100) % CRON_SHARDS;
  const agentIndex = simpleHash(event.driverId) % 84;
  const globalIndex = branch * (TREE_TRIBES * CRON_SHARDS) + tribe * CRON_SHARDS + cronShard;

  return { branch, tribe, cronShard, agentIndex, globalIndex };
}

/** Build the canonical agent ID for a routed shard. */
export function shardToAgentId(shard: TreeOfLifeShard): string {
  return `ys-shard-${String(shard.cronShard).padStart(3, "0")}-agent-${String(shard.agentIndex).padStart(3, "0")}`;
}

/** Estimate reward points from contribution (pre-settlement). */
export function estimateRewardPoints(
  signedEvents: number,
  totalKm: number,
  mandelbrotShards: number,
): number {
  const basePoints = signedEvents * 10;
  const distanceBonus = Math.floor(totalKm * 5);
  const diversityBonus = mandelbrotShards * 25;
  return basePoints + distanceBonus + diversityBonus;
}

function simpleHash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (Math.imul(31, h) + s.charCodeAt(i)) | 0;
  }
  return Math.abs(h);
}
