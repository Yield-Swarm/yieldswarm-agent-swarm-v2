#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib.sh"

CFG="${REPO_ROOT}/deploy/config.env"
[ -f "$CFG" ] || die "deploy/config.env missing — cp deploy/config.env.example deploy/config.env"

require_var GHCR_OWNER
require_var AKASH_KEY_NAME

log "deploy/config.env validated"
