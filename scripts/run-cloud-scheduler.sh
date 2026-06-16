#!/usr/bin/env bash
# Cron entrypoint — run every 5–15 minutes
set -euo pipefail
cd "$(dirname "$0")/.."
export REPO_ROOT="$PWD"
python3 agents/cloud_scheduler_agent.py
