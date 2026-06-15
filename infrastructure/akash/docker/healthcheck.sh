#!/usr/bin/env bash
# healthcheck.sh
# Confirms the workload process is alive AND that the Vault token the
# entrypoint obtained is still valid. If either is false, Docker will
# mark the container unhealthy and Akash provider bidengine will
# eventually evict it.

set -u

# 1. Process check: at least one non-init python process owned by the
#    workload user. Adjust the pattern to match your CMD.
if ! pgrep -u "${YIELDSWARM_RUN_AS:-app}" -f 'yieldswarm' >/dev/null 2>&1; then
    echo "workload process not running" >&2
    exit 1
fi

# 2. Vault token check (best-effort; absence of VAULT_TOKEN means we are
#    pre-bootstrap and Docker should grace us via start-period).
if [[ -n "${VAULT_TOKEN:-}" && -n "${VAULT_ADDR:-}" ]]; then
    if ! vault token lookup -format=json >/dev/null 2>&1; then
        echo "vault token invalid or expired" >&2
        exit 1
    fi
fi

exit 0
