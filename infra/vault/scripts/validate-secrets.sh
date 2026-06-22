#!/usr/bin/env bash
# infra/vault/scripts/validate-secrets.sh
#
# Operator-facing entrypoint (matches SECRETS.md / deploy runbooks).
# Delegates to vault/scripts/validate-secrets.sh in the repo root.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${HERE}/../../.." >/dev/null 2>&1 && pwd)"
TARGET="${REPO_ROOT}/vault/scripts/validate-secrets.sh"

[[ -x "${TARGET}" ]] || {
  echo "missing validate script: ${TARGET}" >&2
  exit 1
}

exec "${TARGET}" "$@"
