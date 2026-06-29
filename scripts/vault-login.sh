#!/usr/bin/env bash
# Wrapper — see terraform/scripts/vault-login.sh and SECRETS.md §5.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/terraform/scripts/vault-login.sh" "$@"
