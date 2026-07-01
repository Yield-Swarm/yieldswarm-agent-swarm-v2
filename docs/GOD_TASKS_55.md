# God Tasks 55 — ZKML Arena (Task #13 Extension)

## Task 13 — ZKML Arena Reputation Scoring

| Field | Value |
|-------|-------|
| Status | **complete** |
| Branch | `cursor/zkml-arena-reputation-597f` |
| Bounty | 100 SOL (critical: circuit soundness, score inflation, privacy leak, sandbox escape) |

### Formula (ZK-verifiable)

```
score = (w₀·win_rate + w₁·consistency + w₂·peer_review + w₃·stake_weight) / (w₀+w₁+w₂+w₃)
```

Weights `[4000, 3000, 2000, 1000]`. Output 0–10000 (display as score/100).

### Artifacts

| Path | Role |
|------|------|
| `circuits/reputation_score.circom` | Groth16 circuit |
| `src/zkml-arena/reputation-engine.js` | Engine (extends `EntropyCore`) |
| `backend/src/routes/arena-zkml.js` | `POST /api/arena/zkml/submit-battle` |
| `programs/swarm_ops/src/reputation.rs` | On-chain PDA anchor |
| `POST /api/bounty` | Bug bounty intake |

### Verify

```bash
npm run test:zkml-arena
cd backend && npm run dev
node scripts/test-zkml-reputation.js
```

### Circuit compile (once)

```bash
cd circuits && npm run compile:reputation && npm run setup:reputation
```
