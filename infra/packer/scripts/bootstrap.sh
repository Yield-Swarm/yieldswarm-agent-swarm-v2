#!/usr/bin/env bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends ca-certificates curl git jq unzip

if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends docker.io
fi

id -u helix >/dev/null 2>&1 || useradd -m -s /bin/bash helix
mkdir -p /opt/helixchain
chown -R helix:helix /opt/helixchain

cat <<'MOTD' >/etc/motd
Helixchain hardened base image
Managed by Packer
MOTD
