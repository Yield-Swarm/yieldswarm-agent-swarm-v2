# =============================================================================
# YieldSwarm AgentSwarm OS — Production Deployment Makefile
# =============================================================================
# Orchestrates the full production deploy. Each target maps to a step in
# DEPLOY.md and to deploy.sh. Run `make help` for the menu, `make deploy` for
# everything in order.
#
# Config is loaded from deploy/config.env (copy from deploy/config.env.example).
# =============================================================================
SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Load deploy config if present (export to recipe sub-shells/scripts).
ifneq (,$(wildcard deploy/config.env))
include deploy/config.env
export
endif

S := deploy/scripts
A := deploy/akash

.PHONY: help deploy all preflight vault-check vault-bootstrap vault-validate-secrets seed-vault \
        akash-deploy-vault akash-preflight akash-verify deploy-akash-europlots \
        akash-bittensor akash-odysseus akash-backend \
        login build build-ghcr push images \
        akash-lease akash-heal akash-heal-stop \
        terraform-init terraform-plan terraform-apply terraform-destroy azure-apply \
        frontend vercel render \
        monitoring-up monitoring-down sovereign-up sovereign-down \
        tesla-keys tesla-register \
        start-sovereign-consensus stop-sovereign-consensus restart-sovereign-consensus \
        multicloud-preflight multicloud-cost-report multicloud-launch multicloud-teardown \
        scale-akash-workers \
        cross-chain-preflight cross-chain-run cross-chain-test \
        smoke smoke-test merge-all-prs merge-all-prs-to-production \
        deploy-production-full wire-domains \
        cloud-scheduler-tick cloud-scheduler-report cloud-scheduler-test \
        build-vllm-rtx5090 deploy-akash-rtx5090-vllm akash-roi-5090 nft-mutation-batch \
        zk-trusted-setup zk-mutation-cycle \
        tfc-setup tfc-init tfc-apply tfc-deploy-all \
        status logs clean production rust-core rust-core-test

## rust-core: build Phase 1 Swarm OS Rust engine
rust-core:
	cargo build -p yieldswarm-core --release
	cargo build -p swarm-core --release

## swarm-accelerator: run 14-elevator Mandelbrot synchrotron
swarm-accelerator:
	cargo run -p swarm-core

## rust-core-test: test yieldswarm-core crate
rust-core-test:
	cargo test -p yieldswarm-core

## help: show this menu
help:
	@echo "YieldSwarm production deployment — make targets:"
	@grep -E '^##' $(MAKEFILE_LIST) | sed -E 's/## ?/  /'
	@echo ""
	@echo "Full ordered deploy:  make deploy"

## deploy: run the FULL production deploy, in order (steps 1-5)
deploy: build akash-lease akash-heal terraform-apply frontend monitoring-up sovereign-up
	@echo ""
	@echo ">>> YieldSwarm deployment complete. See 'make status'."
all: deploy

## preflight: check required tooling is installed
preflight:
	@bash $(S)/lib.sh >/dev/null 2>&1 || true
	@for t in docker terraform python3 vault; do \
	  command -v $$t >/dev/null 2>&1 && echo "  ok   $$t" || echo "  MISS $$t"; \
	done
	@command -v provider-services >/dev/null 2>&1 && echo "  ok   provider-services (akash)" || \
	 (command -v akash >/dev/null 2>&1 && echo "  ok   akash" || echo "  MISS akash CLI (provider-services)")

## vault-check: verify Vault connectivity
vault-check:
	@test -n "$$VAULT_ADDR" || (echo "VAULT_ADDR unset" && exit 1)
	@vault status >/dev/null && echo "  ok   vault reachable"

## vault-validate-secrets: verify KV paths before Terraform / Akash deploy
vault-validate-secrets:
	bash infra/vault/scripts/validate-secrets.sh

## validate-secrets: alias for vault-validate-secrets
validate-secrets: vault-validate-secrets

## akash-deploy-vault: production Akash deploy with Vault runtime injection
akash-deploy-vault:
	bash scripts/akash-deploy-with-vault.sh

## akash-preflight: GO/NO-GO gate before live Akash deploy
akash-preflight:
	bash scripts/akash-preflight.sh

## akash-verify: post-deploy smoke tests against live lease
akash-verify:
	bash scripts/verify-akash-lease.sh

## deploy-akash-europlots: live mainnet deploy to provider.europlots.com
deploy-akash-europlots:
	AKASH_PROVIDER=akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc \
	VAULT_INJECT_RUNTIME_SECRETS=yes \
	bash scripts/deploy-to-akash.sh deploy deploy/deploy-swarm-monolith.yaml

## akash-bittensor: deploy Bittensor miner SDL (requires BT_NETUID)
akash-bittensor:
	bash scripts/deploy-production.sh akash-bittensor

## go-live: disengage dry-run + full rewards sweep (requires HELIX_GO_LIVE=1)
go-live:
	bash scripts/production/go-live.sh

go-live-plan:
	bash scripts/production/go-live.sh --dry-run

azure-swarm-nsg:
	bash scripts/azure/configure-swarm-nsg.sh

## akash-odysseus: deploy Odysseus GPU worker with Vault SDL
akash-odysseus:
	bash scripts/deploy-production.sh akash-odysseus

## akash-backend: deploy light integration API on Akash
akash-backend:
	bash scripts/deploy-production.sh akash-backend

## vault-bootstrap: run Vault setup + seed (requires VAULT_TOKEN)
vault-bootstrap:
	bash scripts/deploy-production.sh vault

## seed-vault: seed KV from operator environment
seed-vault:
	bash vault/scripts/seed-secrets.sh

## azure-apply: apply root terraform/ (Azure Container Apps)
azure-apply:
	bash scripts/deploy-production.sh azure

## vercel: show Vercel deploy instructions / trigger hook
vercel:
	bash scripts/deploy-production.sh vercel

## render: show Render blueprint instructions
render:
	bash scripts/deploy-production.sh render

## production: unified multi-platform entry (see scripts/deploy-production.sh)
production:
	bash scripts/deploy-production.sh all

## deploy-all: full multi-platform stack (Vercel + Render + Akash + monitoring)
deploy-all:
	bash scripts/deploy-all.sh

## deploy-production-full: Vault → Akash → 17 domains → Vercel → Neon → Odysseus
deploy-production-full:
	bash scripts/deploy-production-full.sh

## wire-domains: wire 17 production subdomains (UD + Cloudflare + Vercel)
wire-domains:
	bash scripts/wire-production-domains.sh

deploy-vercel:
	bash scripts/deploy-all.sh vercel

deploy-render:
	bash scripts/deploy-all.sh render

deploy-akash:
	bash scripts/deploy-all.sh akash

deploy-akash-bittensor:
	bash scripts/deploy-all.sh akash-bittensor

# ---- STEP 1: images -------------------------------------------------------
## login: docker login to GHCR (uses GHCR_TOKEN/GHCR_USER)
login:
	@echo "$$GHCR_TOKEN" | docker login ghcr.io -u "$$GHCR_USER" --password-stdin

## build: STEP 1 — build & push all images to GHCR
build images build-ghcr:
	bash $(S)/build-and-push.sh

## push: build & push only (alias of build)
push:
	PUSH=1 bash $(S)/build-and-push.sh

# ---- STEP 2: Akash --------------------------------------------------------
## akash-lease: STEP 2a — create the Akash deployment + lease
akash-lease:
	bash $(A)/create-lease.sh

## akash-heal: STEP 2b — start the Akash auto-heal loop (background)
akash-heal:
	bash $(A)/auto-heal.sh --daemon

## akash-heal-stop: stop the auto-heal daemon
akash-heal-stop:
	@kill $$(cat .run/auto-heal.pid 2>/dev/null) 2>/dev/null && echo "stopped" || echo "not running"

# ---- STEP 3: Terraform ----------------------------------------------------
## terraform-plan: STEP 3 (preview) — plan the multi-cloud fallback
terraform-plan:
	bash $(S)/apply-terraform.sh plan

## terraform-apply: STEP 3 — apply the multi-cloud fallback
terraform-apply:
	bash $(S)/apply-terraform.sh apply

## terraform-destroy: tear down fallback infra
terraform-destroy:
	bash $(S)/apply-terraform.sh destroy

# ---- STEP 4: frontend -----------------------------------------------------
## frontend: STEP 4 — inject real worker URLs into the dashboard config
frontend:
	bash $(S)/update-frontend-urls.sh

# ---- STEP 5: monitoring + loops ------------------------------------------
## monitoring-up: STEP 5a — start Prometheus/Grafana/Alertmanager
monitoring-up:
	bash $(S)/start-monitoring.sh up

## monitoring-down: stop the monitoring stack
monitoring-down:
	bash $(S)/start-monitoring.sh down

## sovereign-up: STEP 5b — start sovereign loops + auto-heal
sovereign-up:
	bash $(S)/start-sovereign-loops.sh start

## sovereign-down: stop sovereign loops
sovereign-down:
	bash $(S)/start-sovereign-loops.sh stop

## start-sovereign-consensus: one-command autonomous loops (alias of sovereign-up)
start-sovereign-consensus: sovereign-up
	@echo "Sovereign Consensus running — check: make status"

## stop-sovereign-consensus: stop autonomous loops
stop-sovereign-consensus: sovereign-down
	@echo "Sovereign Consensus stopped"

## restart-sovereign-consensus: stop, pause, start
restart-sovereign-consensus: stop-sovereign-consensus
	@sleep 3
	@$(MAKE) start-sovereign-consensus

## smoke-test: structural + unit integration smoke suite
smoke-test:
	bash scripts/smoke-test.sh

## smoke: comprehensive post-merge master smoke test
smoke:
	bash scripts/master-smoke-test.sh

## merge-all-prs: safe stacked PR merge (add --push via script args)
merge-all-prs:
	bash scripts/merge-all-prs.sh --dry-run
	@echo ""
	@echo "Dry run above. To merge locally:  bash scripts/merge-all-prs.sh"
	@echo "To merge + push main:            bash scripts/merge-all-prs.sh --push"

## merge-all-prs-to-production: async batch merge open PRs into production
merge-all-prs-to-production:
	bash scripts/merge-all-prs-to-production.sh --push --sync-env

# ---- multi-cloud 30-day utilization --------------------------------------
## multicloud-preflight: GO/NO-GO across Vault, Akash, and optional cloud APIs
multicloud-preflight:
	bash scripts/multicloud-preflight.sh

## multicloud-cost-report: daily utilization + spend snapshot → .run/
multicloud-cost-report:
	bash scripts/multicloud-cost-report.sh

## multicloud-launch: burst worker (PROVIDER=akash|vast|runpod|azure|gcp WORKLOAD=...)
multicloud-launch:
	bash scripts/multicloud/launch-worker.sh

## multicloud-teardown: tear down burst resources (PROVIDER=...)
multicloud-teardown:
	bash scripts/multicloud/teardown-worker.sh

## scale-akash-workers: run lease-manager reconcile (add workers / failover)
scale-akash-workers:
	@python3 akash/lease-manager.py --once

## cross-chain-preflight: GO/NO-GO for cross-chain execution layer
cross-chain-preflight:
	bash scripts/cross-chain-preflight.sh

## cross-chain-run: one-shot strategy batch (dry-run unless CROSS_CHAIN_DRY_RUN=0)
cross-chain-run:
	python3 agents/cross_chain_executor.py

## cross-chain-test: pytest cross-chain + Great Delta routing
cross-chain-test:
	python3 -m pytest tests/test_cross_chain.py tests/test_cross_chain_mvp.py -q

## cloud-scheduler-tick: one async multi-cloud scheduler cycle
cloud-scheduler-tick:
	python3 agents/cloud_scheduler_agent.py

## cloud-scheduler-report: print last scheduler tick + telemetry
cloud-scheduler-report:
	@python3 -c "import json; from pathlib import Path; p=Path('.run/cloud-scheduler-last-tick.json'); print(json.dumps(json.loads(p.read_text()), indent=2) if p.exists() else 'no tick yet — run make cloud-scheduler-tick')"

## cloud-scheduler-test: pytest scheduler + async queue
cloud-scheduler-test:
	python3 -m pytest tests/test_cloud_scheduler.py -q

## build-vllm-rtx5090: build vLLM RTX 5090 Docker image
build-vllm-rtx5090:
	bash scripts/build-vllm-rtx5090-image.sh

## deploy-akash-rtx5090-vllm: deploy vLLM SDL to Akash (requires DEPLOY_IMAGE + wallet)
deploy-akash-rtx5090-vllm:
	bash scripts/deploy-to-akash.sh deploy deploy/akash-rtx5090-vllm.sdl.yml

## akash-roi-5090: print RTX 5090 break-even ROI model
akash-roi-5090:
	@python3 -c "from services.akash_roi import rtx5090_default; import json; print(json.dumps(rtx5090_default(), indent=2))"

## nft-mutation-batch: dry-run weekly Agent NFT mutations from Arena leaderboard
nft-mutation-batch:
	@python3 services/nft_mutation_engine.py --week $$(date +%U)

## zk-trusted-setup: compile entropy_proof.circom + Groth16 ceremony
zk-trusted-setup:
	@bash scripts/zk-trusted-setup.sh

## zk-mutation-cycle: dry-run one ZK mutation cycle (dev proof mode)
zk-mutation-cycle:
	@node --input-type=module -e "import { HardenedAuditEngine } from './src/infrastructure/entropy-core.js'; import { runMutationCycle } from './src/automation/zk-mutation-scheduler.js'; const e=new HardenedAuditEngine(); const r=await runMutationCycle(e,{vramUsedGb:14,tempC:68,utilizationPct:55}); console.log(JSON.stringify(r,null,2));"

## tfc-setup: TFC bootstrap from PR #3 — modular optional addon
tfc-setup:
	@cp -n deploy/terraform-tfc/terraform.tfvars.example deploy/terraform-tfc/terraform.tfvars 2>/dev/null || true

## tfc-init: terraform init for deploy/terraform-tfc/
tfc-init:
	@cd deploy/terraform-tfc && terraform init

## tfc-apply: apply Azure VMSS fallback via Terraform Cloud
tfc-apply:
	@cd deploy/terraform-tfc && terraform apply -var-file=terraform.tfvars

## tfc-deploy-all: setup + init + apply
tfc-deploy-all: tfc-setup tfc-init tfc-apply

# ---- ops ------------------------------------------------------------------
## status: show running loops + monitoring containers
status:
	@bash $(S)/start-sovereign-loops.sh status || true
	@bash $(S)/start-monitoring.sh status || true

## logs: tail the sovereign + auto-heal logs
logs:
	@tail -n 50 -f .run/sovereign-loop.log .run/akash-auto-heal.log 2>/dev/null || echo "no logs yet"

## tesla-keys: generate EC key pair and install public key for Vercel hosting
tesla-keys:
	@./scripts/setup-tesla-keys.sh

## tesla-register: obtain partner token and register domain (TESLA_CLIENT_ID/SECRET/DOMAIN required)
tesla-register:
	@./scripts/register-tesla-fleet.sh $(or $(TESLA_REGION),na)

## clean: remove runtime state (.run) and generated tfvars
clean:
	rm -rf .run deploy/terraform/auto.tfvars.json deploy/terraform/active-backend.json deploy/terraform/fallback-url.txt
	@echo "cleaned runtime state"
