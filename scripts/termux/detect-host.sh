#!/usr/bin/env bash
# Detect Termux / Android host for platform-specific install paths.
set -euo pipefail

is_termux() {
  [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d "${PREFIX:-}/bin" && "$(readlink -f "${PREFIX}/bin/sh" 2>/dev/null || true)" == *com.termux* ]]
}

is_android_userspace() {
  [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]] && [[ -f /system/build.prop || -n "${ANDROID_ROOT:-}" ]]
}

is_proot_ubuntu() {
  [[ -f /etc/os-release ]] && grep -qi 'ubuntu' /etc/os-release 2>/dev/null
}

export YIELDSWARM_HOST_KIND="linux"
if is_proot_ubuntu; then
  export YIELDSWARM_HOST_KIND="proot-ubuntu"
elif is_termux || is_android_userspace; then
  export YIELDSWARM_HOST_KIND="termux-android"
fi

echo "$YIELDSWARM_HOST_KIND"
