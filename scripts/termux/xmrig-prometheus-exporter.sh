#!/usr/bin/env bash
# Prometheus text exporter for Termux XMRig fleet (scrape via node_exporter textfile or curl).
# Usage: ./scripts/termux/xmrig-prometheus-exporter.sh > /var/lib/node_exporter/textfile/xmrig.prom
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/xmrig-status.sh" --prometheus
