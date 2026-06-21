# Cursor Follow-Up Prompts — Three-Solenoid Build

Paste each block into a **separate Cursor agent** for parallel follow-up work.

---

## Prompt A — Solenoid 1 hardening (Nexus Chain)

```
You are hardening Solenoid 1: Nexus Chain in yieldswarm-agent-swarm-v2.

Context: Branch cursor/solenoid-nexus-helix-shadow-4f85 has solenoids/nexus/ (registry, messageBus, resourceManager) and /api/nexus/*.

Tasks:
1. Wire NexusOrchestrator to programs/coordinator on-chain pause via backend CPI helpers.
2. Add Redis/NATS optional backend for CrossSolenoidBus (env NEXUS_BUS_URL).
3. Implement Azure Resource Manager SDK calls in resourceManager.js (real VMSS scale sets).
4. Add integration tests for 521-agent cap edge case.
5. Terraform AppRole for nexus-runtime in vault/terraform-vault-config/auth-approle.tf.

Do not commit secrets. Match existing ESM + Express patterns.
```

---

## Prompt B — Solenoid 2 Helix on-chain deploy

```
You are deploying Solenoid 2: Helix Reverberator on-chain programs.

Context: programs/cross_chain has register_mining_root + route_yield_to_root. config/TREASURY_MANIFEST.json has IoTeX + Mining Roots.

Tasks:
1. anchor build && anchor test — fix any compile errors.
2. Register all 9 mining roots on devnet with weights from helixTreasury.js DEFAULT_WEIGHTS.
3. Extend sdk/helix with routeYieldToRoot() and IoTeX chain_id 4689.
4. Wire YSLR prove_telemetry_bounds into submitZkSwarmBatch when KAIRO_PQC_STUB=0.
5. Add helixBridge.test.js from solenoid2 branch patterns.

Program IDs in Anchor.toml — do not rotate without updating HELIX.md.
```

---

## Prompt C — Solenoid 3 Shadow Chain Arena

```
You are completing Solenoid 3: Shadow Chain Arena (Kyle's chain).

Context: programs/arena integrates swarm_ops AgentRegistry. backend/src/adapters/shadowArena.js has off-chain state.

Tasks:
1. Generate valid Solana keypair for arena program ID (replace placeholder in Anchor.toml).
2. Add anchor tests: register_competitor, submit_zk_swarm_batch (64 proof cap).
3. CPI from arena to swarm_ops for harvest permission checks on reward claim.
4. Connect Arena dashboard frontend/arena to /api/shadow/arena/*.
5. Document Kyle chain governance in docs/SHADOW_CHAIN.md.

Use ZK-Swarm Mutation batched proofs from runtime/zk Vault path.
```

---

## Prompt D — Vault production rollout

```
You are completing HashiCorp Vault integration for all three solenoids.

Context: vault/policies/{nexus,helix,shadow}-runtime.hcl and vault/inject/render-env.sh exist.

Tasks:
1. Add AppRoles nexus-runtime, helix-runtime, shadow-runtime to vault/terraform-vault-config/auth-approle.tf.
2. Wire Akash SDL templates to vault/inject/templates/*.env.ctmpl (replace akash/templates/runtime.env.ctmpl paths).
3. Add Azure Container Instances entrypoint that runs render-env.sh before node start.
4. Add Vast.ai cloud-init user-data snippet in deploy/vastai/.
5. Extend docs/VAULT_ENV_INJECTION.md with solenoid policy table.

Never commit VAULT_TOKEN or SecretIDs.
```

---

## Prompt E — End-to-end sovereign tick

```
Wire the three solenoids into iteration-100 sovereign tick:

1. sovereign_core.py calls POST /api/nexus/status before each tick.
2. On yield event, POST /api/helix/treasury/route with dryRun=false when CROSS_CHAIN_DRY_RUN=0.
3. Arena scores from agents/system/engine.py POST to /api/shadow/arena/score.
4. Vault secrets loaded once at tick start via VAULT_ROLE_ID per solenoid.

Branch from cursor/solenoid-nexus-helix-shadow-4f85.
```
