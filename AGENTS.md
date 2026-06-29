# AGENTS.md

## Cursor Cloud specific instructions

This is the YieldSwarm AgentSwarm OS monorepo. The dependency-install step is handled
by the Cloud Agent update script (see below). This section captures non-obvious
runtime context for working in the repo. Standard commands live in `package.json`,
`backend/package.json`, `frontend/package.json`, and the `README.md` "Payments App"
and "Frontend & Unified Wallet" sections — refer to those rather than duplicating.

### Runnable services (dev mode)

| Service | Dir | Dev command | Port | Notes |
| --- | --- | --- | --- | --- |
| Payments app (primary, Next.js) | repo root | `npm run dev` | 3000 | Main product; serves `/payments`. Boots in demo mode with no secrets. |
| Integration backend (Express) | `backend/` | `npm run dev` | 8080 | Feeds Arena/telemetry; unconfigured upstreams report `connected:false` and fall back. |
| Frontend dApp (Vite + React) | `frontend/` | `npm run dev` | 5173 | Proxies `/api` → `http://127.0.0.1:8080` (set `VITE_BACKEND_URL` to override). |

These services use distinct ports, so all three can run at once.

### Non-obvious caveats

- **No secrets needed for local dev.** The Payments app reads env lazily via
  `src/lib/config/env.ts`; nothing throws at import. Each rail (Stripe/Square/Wise)
  shows as unconfigured (`/api/config` → `rails:{...:false}`) and the store defaults to
  in-memory. `cp .env.example .env` is optional. Auth is an anonymous signed-cookie
  session created automatically on first API call.
- **Web3 deposit needs a treasury address.** `POST /api/deposits/web3` returns HTTP 503
  ("Treasury address for EVM is not configured") until `TREASURY_*` env vars are set.
  This is expected in dev. Wallet *linking* (sign a `/api/wallets/nonce` challenge →
  `POST /api/wallets`) works fully with no secrets and is the simplest end-to-end check.
- **Python deps:** `requirements.txt` only lists `chromadb`, `cryptography`,
  `pycryptodome`, but `hvac` (HashiCorp Vault client) is also imported at runtime by
  `lib/secrets.py` and `kairo/identity/vault_store.py` and is needed for the full
  `python3 -m unittest discover -s tests` suite to pass. The update script installs it.
- **Python env:** `python3 -m venv` is unavailable in this image (no ensurepip), so
  Python packages are installed into the user/system site with
  `pip3 install --break-system-packages`. Console scripts land in `~/.local/bin`.
- The root `tsconfig.json`/`vitest.config.ts` scope only `src/**`; `frontend`,
  `backend`, `kairo`, etc. are excluded and have their own configs/tests.
- **Single Next.js app dir.** App Router lives in `src/app/`. Do NOT create root
  `app/` — Next.js prioritizes it and ignores `src/app/` (`/payments` 404).
  Arena dashboard: `src/app/arena/page.tsx`.
- **`SLIPPAGE_TOLERANCE` breaks Python tests** if exported (fraction vs int bps).
  Run: `env -u SLIPPAGE_TOLERANCE python3 -m unittest discover -s tests`.
- **Mining ethics:** scoped to paid Akash, paid RunPod, and owned hardware only.
  `MINING_PAID_INSTANCES_ONLY=1` (default). No free-credit abuse paths.
- **Encrypted swarm IDs:** PoW/PoS/PoWUI via `lib/encrypted-swarm-id.mjs` —
  `POST /api/swarm/encrypted-id/mint` on integration backend :8080.
- **4-swarm bootstrap:** `npm run swarm:bootstrap` — install, test, encrypted IDs,
  multi-mine dry-run, mesh tick.
- **Hello-world:** `npm run swarm:hello` — wallet nonce/sign flow (no secrets).
- **Physical Control Center:** `npm run control-center:dev` — FastAPI :8095 unified
  hardware dashboard (`docs/CONTROL_CENTER.md`). WebSocket `/api/ws/stream`.

### Lint / test / build (per service)

- Root: `npm run lint`, `npm run typecheck`, `npm run test:unit` (vitest, `src/**/*.test.ts`).
- Frontend: `npm run test:frontend` (node:test). Backend: `npm run test:backend` (node:test).
- Python: `python3 -m unittest discover -s tests -p 'test_*.py'`.
- Aggregate `npm test` also runs frontend+backend; `npm run build` builds the Next.js app.
