#!/usr/bin/env bash
# Hetzner Cloud fallback deployer (invoked by Terraform null_resource.hetzner).
# Provisions a server via the hcloud CLI and runs the worker image with Docker
# through cloud-init.
set -euo pipefail

: "${WORKER_IMAGE:?WORKER_IMAGE required}"
: "${HCLOUD_TOKEN:?HCLOUD_TOKEN required}"
LOCATION="${HETZNER_LOCATION:-ash}"
TYPE="${HETZNER_SERVER_TYPE:-cpx11}"
NAME="${HETZNER_SERVER_NAME:-yieldswarm-worker}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HCLOUD_TOKEN
if ! command -v hcloud >/dev/null 2>&1; then
  echo "[hetzner] hcloud CLI not installed — https://github.com/hetznercloud/cli" >&2
  exit 1
fi

CLOUD_INIT="$(mktemp)"
cat > "$CLOUD_INIT" <<EOF
#cloud-config
package_update: true
packages: [docker.io]
runcmd:
  - systemctl enable --now docker
  - docker run -d --restart=always -p 80:8080 --name worker ${WORKER_IMAGE}
EOF

echo "[hetzner] creating ${TYPE} server '${NAME}' in ${LOCATION}"
hcloud server create \
  --name "$NAME" \
  --type "$TYPE" \
  --image ubuntu-24.04 \
  --location "$LOCATION" \
  --user-data-from-file "$CLOUD_INIT" || true

IP="$(hcloud server ip "$NAME" 2>/dev/null || true)"
rm -f "$CLOUD_INIT"
if [[ -n "$IP" ]]; then
  echo "http://${IP}/healthz" > "${HERE}/../fallback-url.txt"
  echo "[hetzner] live at http://${IP}/healthz"
fi
