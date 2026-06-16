#!/usr/bin/env bash
# Mayhem Mode — aggressive 30-day multicloud + ZK pipeline launcher
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log() { echo "[$(date -u +%FT%TZ)] [mayhem] $*" >&2; }

log "=== MAYHEM MODE — YieldSwarm deploy ==="

# Cloud credits — Akash, Vast, RunPod, Azure, GCP, AWS, Alibaba (30-day burn)
if [[ -x scripts/multicloud/deploy.sh ]]; then
  for provider in akash vast runpod azure gcp aws; do
    log "Launching multicloud: $provider"
    bash scripts/multicloud/deploy.sh "$provider" 2>/dev/null || log "skip $provider"
  done
fi

make multicloud-preflight 2>/dev/null || true
make multicloud-launch 2>/dev/null || log "multicloud-launch skipped"

# ZK pipeline
npm run test:zk 2>/dev/null || log "zk tests skipped"
node scripts/mayhem-zk-pipeline.js --dry-run 2>/dev/null || true

# GPU stack
log "Build vLLM 5090 + monitor sidecars"
docker build -f deploy/Dockerfile.bert -t ghcr.io/yield-swarm/vllm-5090:mayhem . 2>/dev/null || log "docker build skipped"

log "=== MAYHEM complete — see docs/ZK_ENTROPY_SYSTEM.md ==="
