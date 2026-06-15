#!/usr/bin/env bash
set -euo pipefail

template_path="${1:-infra/akash/deployment.sdl.yaml.tpl}"
output_path="${2:-infra/akash/rendered/deployment.sdl.yaml}"

required_vars=(
  AKASH_IMAGE
  VAULT_ADDR
  VAULT_SECRET_PATH
  VAULT_APPROLE_ROLE_ID
  VAULT_WRAPPED_SECRET_ID
)

for name in "${required_vars[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "missing required environment variable: ${name}" >&2
    exit 1
  fi
done

mkdir -p "$(dirname "${output_path}")"

python3 - "${template_path}" "${output_path}" <<'PY'
import os
import stat
import sys
from pathlib import Path
from string import Template

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])

defaults = {
    "APP_ENV": "production",
    "APP_START_COMMAND": "python agents/akash-optimizer.py",
    "VAULT_NAMESPACE": "",
    "VAULT_KV_MOUNT": "apps",
    "VAULT_REQUIRED_SECRET_KEYS": "AGENTSWARM_MASTER_KEY,OPENAI_API_KEY,SOLANA_RPC_URL",
    "AKASH_CPU": "1.0",
    "AKASH_MEMORY": "2Gi",
    "AKASH_EPHEMERAL_SIZE": "10Gi",
    "AKASH_PRICE_AMOUNT": "10000",
    "AKASH_REPLICA_COUNT": "1",
}

values = defaults | dict(os.environ)
rendered = Template(template_path.read_text()).substitute(values)
output_path.write_text(rendered)
output_path.chmod(stat.S_IRUSR | stat.S_IWUSR)
PY

echo "rendered ${output_path}"
