#!/usr/bin/env bash
# Returns: termux-android | termux-proot | linux | unknown
if [[ -d /data/data/com.termux ]]; then
  if [[ -f /proc/version ]] && grep -qiE 'microsoft|ubuntu|debian|proot' /proc/version 2>/dev/null; then
    echo termux-proot
  else
    echo termux-android
  fi
elif [[ "$(uname -s)" == "Linux" ]]; then
  echo linux
else
  echo unknown
fi
