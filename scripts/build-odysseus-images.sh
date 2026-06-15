#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ODYSSEUS_BUILD_CONTEXT="${ODYSSEUS_BUILD_CONTEXT:-https://github.com/pewdiepie-archdaemon/odysseus.git#main}"
ODYSSEUS_IMAGE="${ODYSSEUS_IMAGE:-ghcr.io/yieldswarm/odysseus:main}"
YIELDSWARM_LITELLM_IMAGE="${YIELDSWARM_LITELLM_IMAGE:-ghcr.io/yieldswarm/litellm-router:main}"
PUSH="${PUSH:-false}"

cd "$ROOT_DIR"

docker build \
  --build-arg "INSTALL_OPTIONAL=${ODYSSEUS_INSTALL_OPTIONAL:-false}" \
  -t "$ODYSSEUS_IMAGE" \
  "$ODYSSEUS_BUILD_CONTEXT"

docker build \
  -f docker/litellm-router/Dockerfile \
  -t "$YIELDSWARM_LITELLM_IMAGE" \
  .

if [ "$PUSH" = "true" ]; then
  docker push "$ODYSSEUS_IMAGE"
  docker push "$YIELDSWARM_LITELLM_IMAGE"
fi

cat <<EOF
Built images:
  ODYSSEUS_IMAGE=$ODYSSEUS_IMAGE
  YIELDSWARM_LITELLM_IMAGE=$YIELDSWARM_LITELLM_IMAGE

Set PUSH=true to push both images after build.
EOF
