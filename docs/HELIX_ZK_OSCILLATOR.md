# Helix ZK Oscillator — C¹ + L¹ Timing (Tasks 21-30)

## Role in the 5-layer model

The **Helix Oscillator layer** coordinates *when* ZK proofs run relative to cluster load, mutation cycles, and thermal/VRAM pressure — without blocking Eastern-layer flows.

## Rhythmic schedule

| Event | Period | Component |
|-------|--------|-----------|
| Weekly mutation window | 7 days | `MutationController.mutationInterval` |
| Proof batch tick | dynamic | `ZkProofQueue.nextBatch()` |
| Thermal pause | immediate | queue pauses when GPU > 85°C |
| VRAM pause | immediate | queue pauses when VRAM > 92% |

## Non-linear scheduling (Task 23)

```
batchSize = floor(baseBatchSize × (1 - clusterUtilization))
```

High load → smaller batches. Low load → larger batches up to 16.

## Feedback oscillator (Task 24)

```
if avgProveMs > 3 × targetMs → batchSize -= 1
if avgProveMs < targetMs     → batchSize += 1
```

Slow proving slows mutation rhythm; fast proving accelerates batch throughput.

## Proof queue API

```javascript
import { ZkProofQueue } from '../src/infrastructure/zk-proof-queue.js';

const queue = new ZkProofQueue({ batchSize: 4 });
queue.enqueue({ tokenId: '42', telemetry, mutationTier: 2, entropyQuality: 0.8 });

if (queue.shouldProcessNow({ utilization: 0.6, gpuTempC: 72, vramUsedPct: 70 })) {
  const batch = queue.nextBatch({ utilization: 0.6 });
  // prove batch asynchronously
}
```

## Integration with Sovereign Optimizer (Task 25)

- `proveMs > 15s` → 5% routing score penalty
- `proveMs < 3s` + valid proof → 3% routing boost
- `entropyQuality > 0.7` → up to 12% ZK routing boost

## Logging (Task 28)

`queue.getTimingPatterns()` returns `{ at, batchSize, queueDepth, load }[]` for long-term rhythm analysis.

## Platform participation (Task 30)

The ZK system participates in the broader helix by:

1. Aligning proof batches with weekly mutation windows
2. Deferring work during resource pressure (thermal/VRAM/high load)
3. Feeding proof timing back into optimizer routing decisions
4. Maintaining async Eastern flows via queue + non-blocking prover

See `docs/ZK_ENTROPY_SYSTEM.md` for the full cross-layer review.
