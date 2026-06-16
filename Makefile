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

.PHONY: help deploy all preflight vault-check vault-bootstrap seed-vault \
        akash-deploy-vault akash-bittensor akash-odysseus akash-backend \
        login build push images \
        akash-lease akash-heal akash-heal-stop \
        terraform-init terraform-plan terraform-apply terraform-destroy azure-apply \
        frontend vercel render \
        monitoring-up monitoring-down sovereign-up sovereign-down \
        status logs clean production

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

## akash-deploy-vault: production Akash deploy with Vault runtime injection
akash-deploy-vault:
	bash $(S)/akash-production-deploy.sh

## akash-bittensor: deploy Bittensor miner SDL (requires BT_NETUID)
akash-bittensor:
	bash scripts/deploy-production.sh akash-bittensor

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
build images:
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

# ---- ops ------------------------------------------------------------------
## status: show running loops + monitoring containers
status:
	@bash $(S)/start-sovereign-loops.sh status || true
	@bash $(S)/start-monitoring.sh status || true

## logs: tail the sovereign + auto-heal logs
logs:
	@tail -n 50 -f .run/sovereign-loop.log .run/akash-auto-heal.log 2>/dev/null || echo "no logs yet"

## clean: remove runtime state (.run) and generated tfvars
clean:
	rm -rf .run deploy/terraform/auto.tfvars.json deploy/terraform/active-backend.json deploy/terraform/fallback-url.txt
	@echo "cleaned runtime state"
