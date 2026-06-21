# Phase 2 Follow-Up — swarm_ops Integration & Helix Testing

Paste this into Cursor **after** the Solenoid 2 Helix program + SDK land on your branch.

---

## Prompt block

```markdown
Context: `programs/cross_chain/`, `programs/swarm_ops/`, `programs/coordinator/`, `sdk/helix/`, `HELIX.md`

You are completing Helix ↔ swarm_ops integration and test coverage.

TASKS:

1. **Anchor integration tests** (`tests/helix_bridge.ts`)
   - Deploy all three programs on local validator via `anchor test`.
   - Flow: initialize coordinator → treasury → bridge → swarm_config → register_agent → trigger_remote_harvest → receive_cross_chain_yield.
   - Assert treasury lamports increased and harvest status = Completed.
   - Assert coordinator `set_bridge_pause` blocks new harvests.
   - Assert daily limit in swarm_ops rejects over-limit harvest.

2. **swarm_ops agent batch registration**
   - Add `scripts/register-helix-agents.ts` that registers N agents (default 5 for CI, 521 for prod) with `PERM_HARVEST`.
   - Read agent keypaths from env `HELIX_AGENT_KEY_DIR` — never log secret bytes.

3. **Backend wire-up**
   - Extend `backend/src/routes/helix.js` with `POST /api/helix/settlement/quote` (dry-run default).
   - Use `sdk/helix` HelixClient; respect `NETWORK_LOCKDOWN_MODE` from config.
   - Return `{ nonce, harvestPda, gasEstimate, paused }` without signing.

4. **Python bridge**
   - Add `agents/helix_harvest_agent.py` that calls HelixClient-equivalent via subprocess or HTTP to backend quote endpoint.
   - Ingest receipts into `services/cross_chain/executor.py` format.

5. **CI**
   - Add `.github/workflows/helix-anchor.yml` — `anchor build` + `cd sdk/helix && npm test`.
   - Cache Solana platform tools.

Constraints:
- Do not weaken signature verification on `receive_cross_chain_yield`.
- Keep gospel treasury split (50/30/15/5) in off-chain routing only; on-chain treasury is gross inflow.
- All tests must pass without mainnet keys.

Deliver working tests and scripts; update HELIX.md with the registration command.
```

---

## Quick manual test (localnet)

```bash
anchor test
cd sdk/helix && npm test
curl -s http://127.0.0.1:8080/api/helix/status | jq .
```
