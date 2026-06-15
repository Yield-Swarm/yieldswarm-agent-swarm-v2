/**
 * Mandelbrot / Tree of Life data pipeline models.
 * Signed Kairo telemetry routes into sharded agent tree nodes.
 */

export interface MandelbrotNode {
  nodeId: string;
  shardId: number;
  depth: number;
  parentNodeId: string | null;
  agentCount: number;
  dataPointsIngested: number;
  lastIngestAt: string;
}

export interface IngestRecord {
  id: string;
  driverId: string;
  shardId: number;
  nodeId: string;
  telemetryId: string;
  signature: string;
  ingestedAt: string;
  treePath: number[];
}

export interface MandelbrotIngestRequest {
  driverId: string;
  telemetry: {
    latitude: number;
    longitude: number;
    speedMph: number;
    heading: number;
    tripId?: string;
    sensorHash: string;
    timestamp: string;
  };
  signature: string;
  signerAddress: string;
}

export interface MandelbrotStats {
  totalNodes: number;
  totalIngested: number;
  activeShards: number;
  treeDepth: number;
  formula: string;
}

export const SHARD_FORMULA = '1x3x5x11x1111x1x3x8x9x11';
export const AGENTS_PER_SHARD = 84;
export const TOTAL_SHARDS = 120;
