#!/usr/bin/env bash
# Terraform external data source: probe the primary worker health URL.
# Reads {"url": "..."} on stdin, prints {"healthy": "true|false"} on stdout.
set -euo pipefail

INPUT="$(cat)"
URL="$(printf '%s' "$INPUT" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"

healthy="false"
if [[ -n "$URL" ]]; then
  if curl -fsS --max-time 8 "${URL%/}" >/dev/null 2>&1; then
    healthy="true"
  fi
fi

printf '{"healthy":"%s"}\n' "$healthy"
