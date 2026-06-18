#!/usr/bin/env bash
# deploy/templates/lib/render-template.sh
# Render *.tmpl* files with environment variable substitution.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
RENDER_DIR="${RENDER_DIR:-$ROOT/deploy/rendered}"
TEMPLATES_ROOT="$ROOT/deploy/templates"

usage() {
  cat <<'EOF'
Usage: render-template.sh <target|all>

Targets:
  akash       Render Akash SDL from templates/cloud/akash/
  openclaw    Render OpenClaw mining SDL
  azure       Render Azure env bundle
  aws         Render AWS ECS env bundle
  vast        Render Vast.ai on-demand env bundle
  llm-router  Render LiteLLM/Odysseus docker-compose
  zk-entropy  Render ZK entropy deploy env
  ton-kairo   Render TON + Kairo stack env
  all         Render every target

Environment:
  RENDER_DIR  Output directory (default: deploy/rendered)
  Loads:      deploy/config.env, .env (if present)

EOF
}

load_env() {
  local cfg="$ROOT/deploy/config.env"
  local appenv="$ROOT/.env"
  if [[ -f "$cfg" ]]; then set -a; # shellcheck disable=SC1090
    source "$cfg"; set +a; fi
  if [[ -f "$appenv" ]]; then set -a; # shellcheck disable=SC1090
    source "$appenv"; set +a; fi
  : "${VAULT_ADDR:=https://vault.example.com}"
  : "${VAULT_KV_MOUNT:=yieldswarm}"
  : "${BACKEND_IMAGE:=ghcr.io/yieldswarm/yieldswarm-backend:latest}"
  : "${ODYSSEUS_IMAGE:=ghcr.io/yieldswarm/odysseus:main}"
  : "${LLM_ROUTER_PORT:=4000}"
  : "${API_BASE:=http://127.0.0.1:8080}"
  : "${ZK__CIRCUIT_WASM_PATH:=./circuits/build/entropy_proof_js/entropy_proof.wasm}"
  : "${ZK__ZKEY_PATH:=./circuits/build/entropy_proof_final.zkey}"
  : "${ZK__VERIFIER_ADDRESS:=0x0000000000000000000000000000000000000000}"
  : "${TON_MINI_GAME_CONTRACT:=}"
  : "${KAIRO_TELEMETRY_ENDPOINT:=http://127.0.0.1:8080/api/kairo/telemetry}"
}

render_one() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst < "$src" > "$dst"
  else
  node -e "
    const fs = require('fs');
    const src = process.argv[1];
  let out = fs.readFileSync(src, 'utf8');
  for (const [k, v] of Object.entries(process.env)) {
    if (v == null) continue;
    out = out.split('\${' + k + '}').join(v);
  }
  process.stdout.write(out);
  " "$src" > "$dst"
  fi
  echo "[render] $dst"
}

render_akash() {
  render_one \
    "$TEMPLATES_ROOT/cloud/akash/backend.sdl.tmpl.yml" \
    "$RENDER_DIR/cloud/akash/backend.sdl.yml"
}

render_azure() {
  render_one \
    "$TEMPLATES_ROOT/cloud/azure/container-instance.env.tmpl" \
    "$RENDER_DIR/cloud/azure/container-instance.env"
}

render_aws() {
  render_one \
    "$TEMPLATES_ROOT/cloud/aws/ecs-task.env.tmpl" \
    "$RENDER_DIR/cloud/aws/ecs-task.env"
}

render_vast() {
  render_one \
    "$TEMPLATES_ROOT/cloud/vast/on-demand.env.tmpl" \
    "$RENDER_DIR/cloud/vast/on-demand.env"
}

render_llm_router() {
  render_one \
    "$TEMPLATES_ROOT/llm-router/docker-compose.tmpl.yml" \
    "$RENDER_DIR/llm-router/docker-compose.yml"
}

render_zk_entropy() {
  render_one \
    "$TEMPLATES_ROOT/zk-entropy/deploy.env.tmpl" \
    "$RENDER_DIR/zk-entropy/deploy.env"
}

render_ton_kairo() {
  render_one \
    "$TEMPLATES_ROOT/ton-kairo/stack.env.tmpl" \
    "$RENDER_DIR/ton-kairo/stack.env"
}

render_openclaw() {
  render_one \
    "$TEMPLATES_ROOT/cloud/akash/openclaw.sdl.tmpl.yml" \
    "$RENDER_DIR/cloud/akash/openclaw.sdl.yml"
}

render_all() {
  render_akash
  render_openclaw
  render_azure
  render_aws
  render_vast
  render_llm_router
  render_zk_entropy
  render_ton_kairo
}

main() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then usage; exit 1; fi
  load_env
  mkdir -p "$RENDER_DIR"
  case "$target" in
    akash) render_akash ;;
    openclaw) render_openclaw ;;
    azure) render_azure ;;
    aws) render_aws ;;
    vast) render_vast ;;
    llm-router) render_llm_router ;;
    zk-entropy) render_zk_entropy ;;
    ton-kairo) render_ton_kairo ;;
    all) render_all ;;
    *) echo "Unknown target: $target" >&2; usage; exit 1 ;;
  esac
}

main "$@"
