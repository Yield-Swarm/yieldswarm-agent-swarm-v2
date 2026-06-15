#!/usr/bin/env sh
set -eu

umask 077

log() {
  printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2
}

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "$value" ]; then
    log "Missing required environment variable: $name"
    exit 1
  fi
}

vault_login() {
  if [ -n "${VAULT_TOKEN:-}" ]; then
    log "Using pre-injected VAULT_TOKEN."
    return
  fi

  auth_method="${VAULT_AUTH_METHOD:-kubernetes}"
  case "$auth_method" in
    kubernetes)
      require_env "VAULT_K8S_ROLE"
      jwt_path="${VAULT_K8S_JWT_PATH:-/var/run/secrets/kubernetes.io/serviceaccount/token}"
      auth_path="${VAULT_K8S_AUTH_PATH:-kubernetes}"

      if [ ! -r "$jwt_path" ]; then
        log "Kubernetes JWT not readable at $jwt_path"
        exit 1
      fi

      jwt="$(tr -d '\n' < "$jwt_path")"
      VAULT_TOKEN="$(vault write -field=token "auth/${auth_path}/login" role="$VAULT_K8S_ROLE" jwt="$jwt")"
      export VAULT_TOKEN
      ;;
    approle)
      require_env "VAULT_ROLE_ID"
      require_env "VAULT_SECRET_ID"
      approle_path="${VAULT_APPROLE_PATH:-approle}"
      VAULT_TOKEN="$(vault write -field=token "auth/${approle_path}/login" role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")"
      export VAULT_TOKEN
      ;;
    token)
      require_env "VAULT_TOKEN"
      ;;
    *)
      log "Unsupported VAULT_AUTH_METHOD: $auth_method"
      exit 1
      ;;
  esac
}

fetch_and_export_secret() {
  spec="$1"
  env_name="${spec%%=*}"
  source_spec="${spec#*=}"

  if [ "$env_name" = "$source_spec" ]; then
    log "Invalid VAULT_SECRET_EXPORTS entry (missing '='): $spec"
    exit 1
  fi

  path_spec="${source_spec%%#*}"
  field="${source_spec##*#}"
  if [ "$path_spec" = "$source_spec" ]; then
    log "Invalid VAULT_SECRET_EXPORTS entry (missing '#field'): $spec"
    exit 1
  fi

  mount="${path_spec%%/*}"
  secret_name="${path_spec#*/}"
  if [ "$mount" = "$secret_name" ]; then
    log "Invalid VAULT path in VAULT_SECRET_EXPORTS entry: $spec"
    exit 1
  fi

  value="$(vault kv get -mount="$mount" -field="$field" "$secret_name")"
  if [ -z "$value" ]; then
    log "Fetched empty secret for $env_name from $source_spec"
    exit 1
  fi

  export "$env_name=$value"
}

load_runtime_secrets() {
  require_env "VAULT_ADDR"
  require_env "VAULT_SECRET_EXPORTS"

  vault_login

  old_ifs="$IFS"
  IFS=','
  for raw_spec in $VAULT_SECRET_EXPORTS; do
    spec="$(printf '%s' "$raw_spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$spec" ] || continue
    fetch_and_export_secret "$spec"
  done
  IFS="$old_ifs"

  if [ "${VAULT_UNSET_TOKEN_AFTER_FETCH:-true}" = "true" ]; then
    unset VAULT_TOKEN
  fi
}

main() {
  if [ "$#" -eq 0 ]; then
    log "No command provided to entrypoint."
    exit 1
  fi

  load_runtime_secrets
  exec "$@"
}

main "$@"
