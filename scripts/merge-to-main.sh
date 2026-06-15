#!/usr/bin/env bash
# Fast-forward main to the integrated development branch.
# Run from a clean working tree after reviewing MERGE_STRATEGY.md.
set -euo pipefail

git fetch origin
git checkout main
git merge --ff-only origin/development
git push origin main

echo "main is now at $(git rev-parse --short HEAD)"
echo "Promote to testnet: git checkout testnet && git merge --ff-only main && git push origin testnet"
