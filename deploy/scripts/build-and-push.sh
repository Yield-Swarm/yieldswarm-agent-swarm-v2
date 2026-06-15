#!/usr/bin/env bash
# =============================================================================
# STEP 1 — Build and push Docker images to GHCR.
#
#   deploy/scripts/build-and-push.sh [component ...]
#
# With no args, builds & pushes all three images (worker, agents, dashboard).
# Set DRY_RUN=1 to print the commands without executing them.
# Set PUSH=0 to build locally without pushing.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

PUSH="${PUSH:-1}"
DRY_RUN="${DRY_RUN:-0}"
PLATFORMS="${PLATFORMS:-linux/amd64}"

declare -A DOCKERFILES=(
  [worker]="deploy/docker/Dockerfile.worker"
  [agents]="deploy/docker/Dockerfile.agents"
  [dashboard]="deploy/docker/Dockerfile.dashboard"
  [backend]="deploy/docker/Dockerfile.backend"
  [bittensor-miner]="deploy/docker/Dockerfile.bittensor-miner"
)

COMPONENTS=("$@")
if [[ ${#COMPONENTS[@]} -eq 0 ]]; then
  COMPONENTS=(worker agents dashboard backend bittensor-miner)
fi

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '   %s+ %s%s\n' "$C_YELLOW" "$*" "$C_RESET"
  else
    "$@"
  fi
}

ghcr_login() {
  [[ "$PUSH" == "1" ]] || return 0
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    log "Logging in to ${REGISTRY} as ${GHCR_USER}"
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '   %s+ echo *** | docker login %s -u %s --password-stdin%s\n' \
        "$C_YELLOW" "$REGISTRY" "$GHCR_USER" "$C_RESET"
    else
      echo "${GHCR_TOKEN}" | docker login "${REGISTRY}" -u "${GHCR_USER}" --password-stdin
    fi
  else
    warn "GHCR_TOKEN not set — assuming you are already \`docker login ${REGISTRY}\`'d"
  fi
}

main() {
  step "STEP 1 — Build & push images to GHCR (tag: ${IMAGE_TAG})"
  require docker
  [[ -n "${GHCR_OWNER}" ]] || die "GHCR_OWNER must be set (deploy/config.env)"

  # Prefer buildx when available (multi-arch + better caching).
  local use_buildx=0
  if docker buildx version >/dev/null 2>&1; then use_buildx=1; fi

  ghcr_login

  local c ref df
  for c in "${COMPONENTS[@]}"; do
    df="${DOCKERFILES[$c]:-}"
    [[ -n "$df" ]] || die "unknown component: $c (valid: worker agents dashboard backend bittensor-miner)"
    ref="$(image_ref "$c")"
    step "Building ${c} -> ${ref}"

    if [[ "$use_buildx" == "1" ]]; then
      local push_flag="--load"
      [[ "$PUSH" == "1" ]] && push_flag="--push"
      run docker buildx build \
        --platform "${PLATFORMS}" \
        -f "${REPO_ROOT}/${df}" \
        -t "${ref}" \
        -t "$(image_ref "$c" | sed "s/:${IMAGE_TAG}\$/:latest/")" \
        --build-arg "IMAGE_TAG=${IMAGE_TAG}" \
        "${push_flag}" \
        "${REPO_ROOT}"
    else
      run docker build \
        -f "${REPO_ROOT}/${df}" \
        -t "${ref}" \
        --build-arg "IMAGE_TAG=${IMAGE_TAG}" \
        "${REPO_ROOT}"
      run docker tag "${ref}" "$(image_ref "$c" | sed "s/:${IMAGE_TAG}\$/:latest/")"
      if [[ "$PUSH" == "1" ]]; then
        run docker push "${ref}"
        run docker push "$(image_ref "$c" | sed "s/:${IMAGE_TAG}\$/:latest/")"
      fi
    fi
    ok "${c} image ready: ${ref}"
  done

  step "Image summary"
  for c in "${COMPONENTS[@]}"; do
    printf '   %s\n' "$(image_ref "$c")"
  done
  ok "STEP 1 complete"
}

main "$@"
