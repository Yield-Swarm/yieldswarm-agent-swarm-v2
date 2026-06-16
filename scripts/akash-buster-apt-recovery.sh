#!/usr/bin/env bash
# Recover apt on Akash containers stuck on EOL Debian buster mirrors (404 errors).
# Run inside the Akash Shell tab when curl/ca-certificates cannot install.
#
# Usage (in container):
#   curl -fsSL https://raw.githubusercontent.com/Yield-Swarm/yieldswarm-agent-swarm-v2/main/scripts/akash-buster-apt-recovery.sh | bash
#   # or paste the commands below directly
set -euo pipefail

echo "[akash-apt-recovery] Switching to archive.debian.org mirrors..."

cat > /etc/apt/sources.list <<'EOF'
deb http://archive.debian.org/debian/ buster main
deb http://archive.debian.org/debian-security buster/updates main
EOF

apt-get update -o Acquire::Check-Valid-Until=false
apt-get install -y curl ca-certificates

echo "[akash-apt-recovery] Done. Next:"
echo "  curl -fsSL https://ollama.com/install.sh | sh"
echo "  OLLAMA_HOST=0.0.0.0 ollama serve &"
echo "  ollama pull llama3.1:8b && ollama pull qwen2.5:14b"
