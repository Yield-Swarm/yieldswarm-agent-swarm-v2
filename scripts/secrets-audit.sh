#!/usr/bin/env bash
# Repo-wide secret scan — exit non-zero on likely leaked credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PATTERNS=(
  'ghp_[A-Za-z0-9]{20,}'
  'sk_live_[A-Za-z0-9]{20,}'
  'sk_test_[A-Za-z0-9]{20,}'
  'AKIA[0-9A-Z]{16}'
  'xox[baprs]-[0-9A-Za-z-]{10,}'
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
)

EXCLUDES=(
  --glob '!vault/setup/**'
  --glob '!scripts/lib/vault-env.sh'
  --glob '!scripts/akash-deploy-with-vault.sh'
  --glob '!akash/entrypoint.sh'
  --glob '!terraform/scripts/**'
  --glob '!deploy/akash-odysseus.sdl.yml'
  --glob '!DOMAINS.md'
  --glob '!SECRETS.md'
  --glob '!DEPLOY.md'
  --glob '!.env.example'
  --glob '!node_modules/**'
  --glob '!.git/**'
)

echo "==> Scanning for hardcoded secrets..."
FOUND=0
for pat in "${PATTERNS[@]}"; do
  if rg -n "${EXCLUDES[@]}" -e "$pat" . 2>/dev/null; then
    FOUND=1
  fi
done

# High-entropy quoted assignments (exclude placeholders and vault seed patterns)
if rg -n "${EXCLUDES[@]}" -i \
  -e '(api[_-]?key|secret|password|private[_-]?key|token)\s*[:=]\s*["\x27][^"\x27]{16,}["\x27]' . \
  | rg -v -i 'your_|changeme|example|placeholder|xxx|dummy|test_|\$\(val ' 2>/dev/null; then
  FOUND=1
fi

if (( FOUND )); then
  echo "FAIL: potential secrets found — rotate and remove before merge"
  exit 1
fi

echo "OK: no obvious hardcoded secrets"
