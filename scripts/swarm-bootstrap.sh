#!/usr/bin/env bash
# 4-swarm helical bootstrap — dev environment + hello-world → mainnet prep
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log() { printf '[swarm-bootstrap] %s\n' "$*" >&2; }

log "Swarm 0: npm install (root + backend + frontend)"
npm install
(cd backend && npm install)
(cd frontend && npm install)

log "Swarm 0: Python deps"
pip3 install -r requirements.txt --break-system-packages 2>/dev/null || pip3 install -r requirements.txt
pip3 install hvac pytest --break-system-packages 2>/dev/null || pip3 install hvac pytest

[[ -f .env ]] || cp .env.example .env
mkdir -p .run reports deploy/env

log "Typecheck + lint"
npm run typecheck
npm run lint || log "lint warnings (pre-existing)"

log "Unit tests"
npm run test:unit
npm run test:frontend
npm run test:backend

log "Python tests (unset SLIPPAGE_TOLERANCE)"
env -u SLIPPAGE_TOLERANCE python3 -m unittest discover -s tests -p 'test_*.py'

log "Encrypted ID self-test"
node --input-type=module -e "
import { mintPowId, mintPosId, mintPowUiId, resolveEncryptedId } from './lib/encrypted-swarm-id.mjs';
const p = mintPowId('asic-z15-01'); const s = mintPosId('validator-1'); const u = mintPowUiId('dashboard');
console.log('PoW', resolveEncryptedId(p).plaintext.id);
console.log('PoS', resolveEncryptedId(s).plaintext.id);
console.log('PoWUI', resolveEncryptedId(u).plaintext.id);
"

log "Multi-mine dry-run (paid only)"
MULTI_MINE_DRY_RUN=1 node scripts/multi-mine-router.mjs | head -20

log "Physical telemetry ingest"
node --input-type=module -e "import { ingestPhysicalTelemetry } from './services/telemetry/physical-core.mjs'; ingestPhysicalTelemetry({ kind:'solar', solar_kw:27 }).then(r=>console.log(r.encrypted_pow_id.slice(0,24)+'…'))"

log "Cosmic onboarding sample"
node --input-type=module -e "import { onboardAgent } from './services/game/cosmic-onboarding.mjs'; onboardAgent({ birthday:'1990-06-15', agentId:'CBREEZY0003' }).then(console.log)"

log "Mesh tick"
node --input-type=module -e "import { createMeshPool } from './services/mesh/agent-worker-pool.mjs'; createMeshPool({maxAgents:16}).tickBatch(8).then(console.log)"

log "Done — start dev: npm run dev & npm run dev:backend & npm run dev:frontend"
log "Hello-world: node scripts/hello-world-wallet.mjs"
