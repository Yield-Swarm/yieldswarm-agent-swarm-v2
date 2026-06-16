#!/usr/bin/env bash
# Mandelbrot bot — one-shot drive sim + Helix snapshot → Neon (or JSONL fallback).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

export MANDELBROT_BOT_ONESHOT="${MANDELBROT_BOT_ONESHOT:-1}"
export KAIRO_STORE_DIR="${KAIRO_STORE_DIR:-$REPO_ROOT/.data/kairo}"
export NEON_FALLBACK_DIR="${NEON_FALLBACK_DIR:-$REPO_ROOT/.data/neon}"

python3 agents/mandelbrot_bot.py
