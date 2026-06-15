#!/usr/bin/env bash
# =============================================================================
# STEP 2a — Create the Akash deployment + lease for YieldSwarm.
#
#   deploy/akash/create-lease.sh
#
# Flow: render SDL -> ensure client cert -> create deployment -> wait for bids
#       -> accept cheapest bid (create lease) -> send manifest -> print URIs.
#
# Requires the Akash CLI. Modern installs ship `provider-services`; older ones
# ship `akash`. Either is auto-detected (override with AKASH_BIN).
# Writes lease metadata + derived worker URLs to .run/akash-lease.env.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"
load_config
ensure_run_dir

AKASH_BIN="${AKASH_BIN:-}"
LEASE_ENV="${REPO_ROOT}/${RUN_DIR}/akash-lease.env"
RENDERED_SDL="${REPO_ROOT}/${RUN_DIR}/deploy.sdl.rendered.yaml"
BID_TIMEOUT="${AKASH_BID_TIMEOUT:-120}"

detect_cli() {
  if [[ -n "$AKASH_BIN" ]]; then return; fi
  if have provider-services; then AKASH_BIN="provider-services";
  elif have akash; then AKASH_BIN="akash";
  else die "Akash CLI not found. Install 'provider-services' (https://akash.network/docs)"; fi
  log "Using Akash CLI: ${AKASH_BIN}"
}

akq() {
  # Common tx/query flags.
  "$AKASH_BIN" "$@" \
    --node "$AKASH_NODE" \
    --chain-id "$AKASH_CHAIN_ID" \
    --keyring-backend "$AKASH_KEYRING_BACKEND" \
    -o json
}

render_sdl() {
  step "Rendering SDL with GHCR image refs"
  local worker agents dashboard
  worker="$(image_ref worker)"; agents="$(image_ref agents)"; dashboard="$(image_ref dashboard)"
  sed \
    -e "s|__WORKER_IMAGE__|${worker}|g" \
    -e "s|__AGENTS_IMAGE__|${agents}|g" \
    -e "s|__DASHBOARD_IMAGE__|${dashboard}|g" \
    "${REPO_ROOT}/${AKASH_SDL}" > "${RENDERED_SDL}"
  ok "Rendered -> ${RENDERED_SDL}"
}

ensure_cert() {
  step "Ensuring Akash client certificate"
  if "$AKASH_BIN" tx cert generate client --from "$AKASH_KEY_NAME" \
        --keyring-backend "$AKASH_KEYRING_BACKEND" 2>/dev/null; then
    log "Generated client cert (publishing on-chain)"
    "$AKASH_BIN" tx cert publish client --from "$AKASH_KEY_NAME" \
      --node "$AKASH_NODE" --chain-id "$AKASH_CHAIN_ID" \
      --keyring-backend "$AKASH_KEYRING_BACKEND" \
      --gas "$AKASH_GAS" --gas-adjustment "$AKASH_GAS_ADJUSTMENT" \
      --gas-prices "$AKASH_GAS_PRICES" -y || warn "cert publish skipped (may already exist)"
  else
    log "Client cert already present"
  fi
}

owner_address() {
  "$AKASH_BIN" keys show "$AKASH_KEY_NAME" -a --keyring-backend "$AKASH_KEYRING_BACKEND"
}

create_deployment() {
  step "Creating deployment on ${AKASH_CHAIN_ID}"
  local out
  out="$(akq tx deployment create "${RENDERED_SDL}" \
    --from "$AKASH_KEY_NAME" \
    --gas "$AKASH_GAS" --gas-adjustment "$AKASH_GAS_ADJUSTMENT" \
    --gas-prices "$AKASH_GAS_PRICES" -y)"
  echo "$out" > "${REPO_ROOT}/${RUN_DIR}/akash-deploy-tx.json"
  # DSEQ = block height of the deployment tx.
  DSEQ="$(echo "$out" | grep -oE '"height":"?[0-9]+' | head -1 | grep -oE '[0-9]+')"
  [[ -n "$DSEQ" ]] || die "could not determine DSEQ from deployment tx"
  OWNER="$(owner_address)"
  ok "Deployment created: owner=${OWNER} dseq=${DSEQ}"
}

wait_for_bid() {
  step "Waiting for provider bids (timeout ${BID_TIMEOUT}s)"
  local elapsed=0 bids
  while (( elapsed < BID_TIMEOUT )); do
    bids="$(akq query market bid list --owner "$OWNER" --dseq "$DSEQ" 2>/dev/null || echo '{}')"
    if echo "$bids" | grep -q '"bid_id"'; then
      ok "Bids received"
      echo "$bids" > "${REPO_ROOT}/${RUN_DIR}/akash-bids.json"
      return 0
    fi
    sleep 5; elapsed=$((elapsed + 5))
    printf '   ...waited %ss\n' "$elapsed"
  done
  die "no bids within ${BID_TIMEOUT}s — try raising pricing in ${AKASH_SDL}"
}

pick_provider() {
  # Choose the cheapest provider bid.
  PROVIDER="$(python3 - "$REPO_ROOT/$RUN_DIR/akash-bids.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
bids = data.get("bids", [])
def price(b):
    try: return int(b["bid"]["price"]["amount"])
    except Exception: return 10**18
best = min(bids, key=price) if bids else None
print(best["bid"]["bid_id"]["provider"] if best else "")
PY
)"
  [[ -n "$PROVIDER" ]] || die "could not select a provider from bids"
  ok "Selected provider: ${PROVIDER}"
}

create_lease() {
  step "Creating lease with provider ${PROVIDER}"
  akq tx market lease create \
    --owner "$OWNER" --dseq "$DSEQ" --gseq 1 --oseq 1 --provider "$PROVIDER" \
    --from "$AKASH_KEY_NAME" \
    --gas "$AKASH_GAS" --gas-adjustment "$AKASH_GAS_ADJUSTMENT" \
    --gas-prices "$AKASH_GAS_PRICES" -y >/dev/null
  ok "Lease created"
}

send_manifest() {
  step "Sending manifest to provider"
  "$AKASH_BIN" send-manifest "${RENDERED_SDL}" \
    --node "$AKASH_NODE" \
    --dseq "$DSEQ" --provider "$PROVIDER" \
    --from "$AKASH_KEY_NAME" --keyring-backend "$AKASH_KEYRING_BACKEND" \
    || warn "send-manifest reported an issue; check 'lease-status'"
  ok "Manifest sent"
}

emit_lease_env() {
  step "Resolving lease URIs"
  local status uris
  status="$("$AKASH_BIN" lease-status \
    --node "$AKASH_NODE" --dseq "$DSEQ" --provider "$PROVIDER" \
    --from "$AKASH_KEY_NAME" --keyring-backend "$AKASH_KEYRING_BACKEND" 2>/dev/null || echo '{}')"
  echo "$status" > "${REPO_ROOT}/${RUN_DIR}/akash-lease-status.json"
  uris="$(echo "$status" | grep -oE 'https?://[a-zA-Z0-9._/-]+' | sort -u | paste -sd, -)"

  {
    echo "# Generated by create-lease.sh on $(date -u +%FT%TZ)"
    echo "AKASH_OWNER=${OWNER}"
    echo "AKASH_DSEQ=${DSEQ}"
    echo "AKASH_PROVIDER=${PROVIDER}"
    echo "AKASH_WORKER_URLS=${uris}"
  } > "${LEASE_ENV}"
  ok "Lease metadata -> ${LEASE_ENV}"
  [[ -n "$uris" ]] && ok "Worker URIs: ${uris}" || warn "No URIs resolved yet; re-run lease-status shortly"
}

main() {
  step "STEP 2a — Akash lease creation"
  detect_cli
  require python3
  render_sdl
  ensure_cert
  create_deployment
  wait_for_bid
  pick_provider
  create_lease
  send_manifest
  sleep 8
  emit_lease_env
  ok "STEP 2a complete — lease live (dseq=${DSEQ}, provider=${PROVIDER})"
  echo
  log "Start auto-healing with: deploy/akash/auto-heal.sh"
}

main "$@"
