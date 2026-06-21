#!/usr/bin/env bash
# Print Alchemy default RPC URLs when ALCHEMY_API_KEY is set (keys redacted in output).
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../.." && pwd)"
cd "${REPO_ROOT}"
node --input-type=module -e "
import { resolveAlchemyDefaults, getAlchemyApiKey } from './backend/src/lib/alchemy.js';
const key = getAlchemyApiKey();
if (!key) { console.error('ALCHEMY_API_KEY not set'); process.exit(1); }
const d = resolveAlchemyDefaults(key);
for (const [k,v] of Object.entries(d)) console.log(k + '=' + v.replace(key, '***'));
"
