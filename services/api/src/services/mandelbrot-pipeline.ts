import { createHash } from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import type {
  MandelbrotNode,
  IngestRecord,
  MandelbrotIngestRequest,
  MandelbrotStats,
} from '../models/mandelbrot.js';
import {
  SHARD_FORMULA,
  AGENTS_PER_SHARD,
  TOTAL_SHARDS,
} from '../models/mandelbrot.js';
import { getDriver } from './kairo-identity.js';

const nodes = new Map<string, MandelbrotNode>();
const ingestLog: IngestRecord[] = [];

function initShardNodes() {
  if (nodes.size > 0) return;
  for (let shard = 0; shard < TOTAL_SHARDS; shard++) {
    const nodeId = `mandelbrot-shard-${shard}-root`;
    nodes.set(nodeId, {
      nodeId,
      shardId: shard,
      depth: 0,
      parentNodeId: null,
      agentCount: AGENTS_PER_SHARD,
      dataPointsIngested: 0,
      lastIngestAt: new Date().toISOString(),
    });
  }
}

function computeTreePath(shardId: number, sensorHash: string): number[] {
  const hash = createHash('sha256').update(`${shardId}:${sensorHash}`).digest();
  return Array.from(hash.subarray(0, 8));
}

function verifySignature(req: MandelbrotIngestRequest): boolean {
  const driver = getDriver(req.driverId);
  if (!driver) return false;
  return driver.evmAddress.toLowerCase() === req.signerAddress.toLowerCase();
}

export function ingestToMandelbrot(req: MandelbrotIngestRequest): IngestRecord | null {
  initShardNodes();

  if (!verifySignature(req)) return null;

  const shardId =
    parseInt(
      createHash('sha256')
        .update(`${req.telemetry.latitude},${req.telemetry.longitude}`)
        .digest('hex')
        .slice(0, 2),
      16
    ) % TOTAL_SHARDS;

  const nodeId = `mandelbrot-shard-${shardId}-root`;
  const node = nodes.get(nodeId)!;
  node.dataPointsIngested++;
  node.lastIngestAt = new Date().toISOString();

  const record: IngestRecord = {
    id: uuidv4(),
    driverId: req.driverId,
    shardId,
    nodeId,
    telemetryId: uuidv4(),
    signature: req.signature,
    ingestedAt: new Date().toISOString(),
    treePath: computeTreePath(shardId, req.telemetry.sensorHash),
  };

  ingestLog.push(record);
  return record;
}

export function getStats(): MandelbrotStats {
  initShardNodes();
  const activeShards = [...nodes.values()].filter((n) => n.dataPointsIngested > 0).length;
  return {
    totalNodes: nodes.size,
    totalIngested: ingestLog.length,
    activeShards,
    treeDepth: 8,
    formula: SHARD_FORMULA,
  };
}

export function getShardNodes(shardId?: number): MandelbrotNode[] {
  initShardNodes();
  const all = [...nodes.values()];
  return shardId !== undefined ? all.filter((n) => n.shardId === shardId) : all;
}

export function getIngestLog(driverId?: string, limit = 100): IngestRecord[] {
  const filtered = driverId
    ? ingestLog.filter((r) => r.driverId === driverId)
    : ingestLog;
  return filtered.slice(-limit);
}
