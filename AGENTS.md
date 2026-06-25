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
- **Single Next.js app dir.** The Payments app's App Router lives in `src/app/`.
 Do NOT create a root-level `app/` directory: when both `app/` and `src/app/`
 exist, Next.js uses root `app/` and silently ignores all of `src/app/`, so
 `/payments` and every `/api/*` route 404. The Akash arena dashboard lives at
 `src/app/arena/page.tsx`; keep new routes under `src/app/`.
- **`SLIPPAGE_TOLERANCE` breaks a Python test if exported.** `.env.example`
 ships `SLIPPAGE_TOLERANCE=0.005` (a fraction), but `services/cross_chain/jupiter.py`
 parses it with `int(...)` (basis points). If that var is present in the shell
 env, `tests/test_node5.py` fails with `invalid literal for int()`. Run the
 Python suite with `env -u SLIPPAGE_TOLERANCE python3 -m unittest discover -s tests`
 if the var is injected.
- **`pytest` is a test-only dep** imported by `tests/test_mining_manager.py` and
 `tests/test_node5.py` but not listed in `requirements.txt`. The update script
 installs it (alongside `hvac`).
- **Payments hello-world:** `node scripts/hello-world-wallet.mjs` exercises the
 app end-to-end (anonymous session → `/api/wallets/nonce` → EVM signature →
 `/api/wallets`) with zero secrets — the quickest smoke check that the app runs.

### Lint / test / build (per service)

- Root: `npm run lint`, `npm run typecheck`, `npm run test:unit` (vitest, `src/**/*.test.ts`).
- Frontend: `npm run test:frontend` (node:test). Backend: `npm run test:backend` (node:test).
- Python: `python3 -m unittest discover -s tests -p 'test_*.py'`.
- Aggregate `npm test` also runs frontend+backend; `npm run build` builds the Next.js app.
