/**
 * ZK Proof Queue — Helix Oscillator scheduling (C¹ + L¹ Tasks 21-30).
 * @module src/infrastructure/zk-proof-queue
 */

import { MONITOR_LIMITS } from './monitor-limits.js';

const MUTATION_WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_BATCH_SIZE = 4;

export class ZkProofQueue {
  constructor(opts = {}) {
    this.queue = [];
    this.paused = false;
    this.batchSize = opts.batchSize ?? DEFAULT_BATCH_SIZE;
    this.timingLog = [];
    this.loadThreshold = opts.loadThreshold ?? 0.85;
    this.thermalLimitC = opts.thermalLimitC ?? MONITOR_LIMITS.THERMAL_C;
    this.vramLimitGb = opts.vramLimitGb ?? MONITOR_LIMITS.VRAM_MAX_GB;
    this.vramLimitPct = opts.vramLimitPct ?? MONITOR_LIMITS.VRAM_MAX_PCT_RTX5090;
  }

  /** Task 29 — enqueue with rhythmic priority */
  enqueue(job) {
    const priority = computePriority(job);
    this.queue.push({ ...job, priority, enqueuedAt: Date.now() });
    this.queue.sort((a, b) => b.priority - a.priority);
    return this.queue.length;
  }

  /** Task 26-27 — decide whether to prove now or defer */
  shouldProcessNow(clusterState = {}) {
    if (this.paused) return false;
    if (this.queue.length === 0) return false;

    if ((clusterState.utilization ?? 0) > this.loadThreshold) return false;
    if ((clusterState.gpuTempC ?? 0) > this.thermalLimitC) {
      this.paused = true;
      return false;
    }
    const vramGb = clusterState.vramUsedGb ??
      ((clusterState.vramUsedPct ?? 0) / 100) * MONITOR_LIMITS.VRAM_TOTAL_GB_RTX5090;
    if (vramGb > this.vramLimitGb || (clusterState.vramUsedPct ?? 0) > this.vramLimitPct) return false;

    return true;
  }

  /** Task 23 — non-linear batch sizing from load + entropy quality */
  nextBatch(clusterState = {}) {
    if (!this.shouldProcessNow(clusterState)) return [];

    const load = clusterState.utilization ?? 0.5;
    const dynamicSize = Math.max(1, Math.floor(this.batchSize * (1 - load)));

    const batch = this.queue.splice(0, dynamicSize);
    this.timingLog.push({
      at: Date.now(),
      batchSize: batch.length,
      queueDepth: this.queue.length,
      load,
    });
    return batch;
  }

  /** Task 21 — align with weekly mutation rhythm */
  isMutationWindowDue(lastMutationAt) {
    return Date.now() - (lastMutationAt ?? 0) >= MUTATION_WEEK_MS;
  }

  /** Task 24 — oscillator feedback: slow mutations if proving is slow */
  adjustRhythm(avgProveMs, targetMs = 5000) {
    if (avgProveMs > targetMs * 3) {
      this.batchSize = Math.max(1, this.batchSize - 1);
    } else if (avgProveMs < targetMs) {
      this.batchSize = Math.min(16, this.batchSize + 1);
    }
    return this.batchSize;
  }

  resume() {
    this.paused = false;
  }

  getTimingPatterns() {
    return [...this.timingLog];
  }
}

function computePriority(job) {
  const quality = job.entropyQuality ?? 0.5;
  const tier = job.mutationTier ?? 0;
  const age = Date.now() - (job.enqueuedAt ?? Date.now());
  return quality * 100 + tier * 10 + age / 60_000;
}

export default ZkProofQueue;
