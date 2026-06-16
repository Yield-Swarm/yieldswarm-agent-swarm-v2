#!/usr/bin/env bash
# vault/scripts/issue-secret-id.sh
#
# Issue a response-wrapped Secret ID for one of the AppRoles created by
# bootstrap.sh. The wrapping token is single-use and short-lived: hand it to
# the consumer over a channel that does NOT log it. The consumer unwraps once
# to obtain the actual Secret ID, then logs in.
#
# Usage:
#   ./vault/scripts/issue-secret-id.sh <role>            # default wrap_ttl=5m
#   ./vault/scripts/issue-secret-id.sh <role> 15m
#
# <role> in: terraform | ci | akash-runtime | integration-backend | bittensor-runtime
#            | odysseus-runtime | payments-runtime | multicloud-operator | beefcake-runtime
#
# Prints two values on stdout in shell-export form so it can be `eval`'d:
#   VAULT_ROLE_ID=...
#   VAULT_SECRET_ID_WRAP_TOKEN=...     # one-shot, expires in <wrap_ttl>
#   VAULT_WRAPPED_SECRET_ID=...        # alias for Akash SDL / entrypoints
#
# Do NOT pipe this script's output into a logged file. Use TTY only, or pipe
# directly into the consumer's secure delivery channel.

set -Eeuo pipefail
: "${VAULT_ADDR:?}"
: "${VAULT_TOKEN:?}"

ROLE="${1:-}"
WRAP_TTL="${2:-5m}"

case "${ROLE}" in
  terraform|ci|akash-runtime|integration-backend|bittensor-runtime|odysseus-runtime|payments-runtime|multicloud-operator|beefcake-runtime) ;;
  *) echo "usage: $0 <terraform|ci|akash-runtime|integration-backend|bittensor-runtime|odysseus-runtime|payments-runtime|multicloud-operator|beefcake-runtime> [wrap_ttl]" >&2; exit 2 ;;
esac

ROLE_ID="$(vault read -field=role_id "auth/approle/role/${ROLE}/role-id")"
WRAP_TOKEN="$(VAULT_WRAP_TTL="${WRAP_TTL}" vault write -field=wrapping_token -f "auth/approle/role/${ROLE}/secret-id")"

cat <<EOF
VAULT_ROLE_ID=${ROLE_ID}
VAULT_SECRET_ID_WRAP_TOKEN=${WRAP_TOKEN}
VAULT_WRAPPED_SECRET_ID=${WRAP_TOKEN}
EOF
