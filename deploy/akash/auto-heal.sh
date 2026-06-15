#!/usr/bin/env bash
# =============================================================================
# STEP 2b — Akash lease auto-healing loop.
#
#   deploy/akash/auto-heal.sh            # run in foreground
#   deploy/akash/auto-heal.sh --once     # single health check (for cron)
#   deploy/akash/auto-heal.sh --daemon   # background, pid in .run/auto-heal.pid
#
# Continuously:
#   * keeps the lease funded (tops up the escrow account when balance is low)
#   * probes worker /healthz; on failure re-sends the manifest
#   * if the lease is closed, recreates it via create-lease.sh
#
# Reads lease metadata from .run/akash-lease.env (written by create-lease.sh).
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"
load_config
ensure_run_dir

AKASH_BIN="${AKASH_BIN:-}"
LEASE_ENV="${REPO_ROOT}/${RUN_DIR}/akash-lease.env"
PID_FILE="${REPO_ROOT}/${RUN_DIR}/auto-heal.pid"
LOG_FILE="${REPO_ROOT}/${RUN_DIR}/auto-heal.log"
DEPOSIT="${AKASH_DEPOSIT:-5000000uakt}"

detect_cli() {
  if [[ -n "$AKASH_BIN" ]]; then return; fi
  if have provider-services; then AKASH_BIN="provider-services";
  elif have akash; then AKASH_BIN="akash";
  else die "Akash CLI not found"; fi
}

load_lease() {
  [[ -f "$LEASE_ENV" ]] || die "lease env missing: ${LEASE_ENV} (run create-lease.sh first)"
  # shellcheck disable=SC1090
  source "$LEASE_ENV"
  : "${AKASH_OWNER:?}" "${AKASH_DSEQ:?}" "${AKASH_PROVIDER:?}"
}

lease_active() {
  local out
  out="$("$AKASH_BIN" query market lease list \
    --owner "$AKASH_OWNER" --dseq "$AKASH_DSEQ" \
    --node "$AKASH_NODE" -o json 2>/dev/null || echo '{}')"
  echo "$out" | grep -q '"state": *"active"' || echo "$out" | grep -q '"state":"active"'
}

escrow_balance() {
  "$AKASH_BIN" query deployment get \
    --owner "$AKASH_OWNER" --dseq "$AKASH_DSEQ" \
    --node "$AKASH_NODE" -o json 2>/dev/null \
    | grep -oE '"balance":\{[^}]*"amount":"?[0-9]+' | grep -oE '[0-9]+$' | head -1
}

topup() {
  step "Topping up deployment escrow (+${DEPOSIT})"
  "$AKASH_BIN" tx deployment deposit "$DEPOSIT" \
    --owner "$AKASH_OWNER" --dseq "$AKASH_DSEQ" \
    --from "$AKASH_KEY_NAME" --keyring-backend "$AKASH_KEYRING_BACKEND" \
    --node "$AKASH_NODE" --chain-id "$AKASH_CHAIN_ID" \
    --gas "$AKASH_GAS" --gas-adjustment "$AKASH_GAS_ADJUSTMENT" \
    --gas-prices "$AKASH_GAS_PRICES" -y >/dev/null 2>&1 \
    && ok "escrow topped up" || warn "top-up tx failed (will retry next cycle)"
}

resend_manifest() {
  local rendered="${REPO_ROOT}/${RUN_DIR}/deploy.sdl.rendered.yaml"
  [[ -f "$rendered" ]] || { warn "rendered SDL missing; cannot resend manifest"; return 1; }
  "$AKASH_BIN" send-manifest "$rendered" \
    --node "$AKASH_NODE" --dseq "$AKASH_DSEQ" --provider "$AKASH_PROVIDER" \
    --from "$AKASH_KEY_NAME" --keyring-backend "$AKASH_KEYRING_BACKEND" \
    >/dev/null 2>&1 && ok "manifest re-sent" || warn "manifest resend failed"
}

worker_healthy() {
  [[ -n "${AKASH_WORKER_URLS:-}" ]] || return 0  # nothing to probe yet
  local url ok_any=1
  IFS=',' read -ra urls <<< "$AKASH_WORKER_URLS"
  for url in "${urls[@]}"; do
    [[ -z "$url" ]] && continue
    if curl -fsS --max-time 8 "${url%/}/healthz" >/dev/null 2>&1; then ok_any=0; fi
  done
  return $ok_any
}

recreate_lease() {
  step "Lease not active — recreating via create-lease.sh"
  bash "${REPO_ROOT}/deploy/akash/create-lease.sh" \
    && load_lease \
    && ok "lease recreated" || warn "lease recreation failed (will retry)"
}

cycle() {
  local ts; ts="$(date -u +%FT%TZ)"
  if ! lease_active; then
    warn "[${ts}] lease inactive"
    recreate_lease
    return
  fi

  local bal; bal="$(escrow_balance || echo '')"
  if [[ -n "$bal" ]]; then
    if (( bal < AKASH_MIN_BALANCE_UAKT )); then
      warn "[${ts}] escrow low: ${bal}uakt < ${AKASH_MIN_BALANCE_UAKT}uakt"
      topup
    else
      log "[${ts}] escrow ok: ${bal}uakt"
    fi
  fi

  if worker_healthy; then
    ok "[${ts}] workers healthy"
  else
    warn "[${ts}] worker health check failed — resending manifest"
    resend_manifest
  fi
}

run_loop() {
  step "STEP 2b — Akash auto-heal loop (interval ${AKASH_HEAL_INTERVAL}s)"
  while true; do
    cycle
    sleep "$AKASH_HEAL_INTERVAL"
  done
}

main() {
  detect_cli
  load_lease
  case "${1:-}" in
    --once)   cycle ;;
    --daemon)
      ensure_run_dir
      nohup bash "$0" >/dev/null 2>>"$LOG_FILE" &
      echo $! > "$PID_FILE"
      ok "auto-heal daemon started (pid $(cat "$PID_FILE"), log ${LOG_FILE})" ;;
    *)        run_loop ;;
  esac
}

main "$@"
