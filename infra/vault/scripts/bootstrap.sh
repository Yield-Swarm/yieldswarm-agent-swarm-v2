#!/usr/bin/env bash
# infra/vault/scripts/bootstrap.sh
#
# Operator-facing entrypoint (matches SECRETS.md / deploy runbooks).
# Delegates to vault/scripts/bootstrap.sh in the repo root.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${HERE}/../../.." >/dev/null 2>&1 && pwd)"
TARGET="${REPO_ROOT}/vault/scripts/bootstrap.sh"

[[ -x "${TARGET}" ]] || {
  echo "missing bootstrap script: ${TARGET}" >&2
  exit 1
}

exec "${TARGET}" "$@"
