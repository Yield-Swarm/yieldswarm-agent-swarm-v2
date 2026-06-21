#!/usr/bin/env bash
# scripts/full-stack-optimize.sh — Termux-friendly wrapper for deploy/optimize-all.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/deploy/optimize-all.sh" "$@"
