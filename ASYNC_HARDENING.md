# Async / Axios / Cron Hardening Summary

Backend reliability pass (God Prompt Task 3).

## Changes

| File | Change |
|------|--------|
| `backend/package.json` | Added `axios`, `node-cron` |
| `backend/src/lib/httpClient.js` | **New** — axios client with retries, timeouts, `UpstreamError` |
| `backend/src/lib/http.js` | Re-exports `httpClient` (backward compatible) |
| `backend/src/jobs/cron.js` | **New** — background polls for Akash, treasury, emission |
| `backend/src/server.js` | Starts cron jobs on boot |
| `backend/src/config.js` | `httpRetries`, `httpRetryDelayMs`, `cronJobsEnabled` |

## Behavior

- **Retries:** 2 retries (configurable via `HTTP_RETRIES`) with linear backoff
- **Timeout:** `UPSTREAM_TIMEOUT_MS` (default 6s) per request
- **Cron schedules:**
  - Akash workers: `*/2 * * * *` (`CRON_AKASH_POLL`)
  - Treasury splits: `*/5 * * * *` (`CRON_TREASURY_POLL`)
  - Emission router: `*/5 * * * *` (`CRON_EMISSION_POLL`)
- **Non-blocking:** Cron failures log to stderr; server keeps running
- **Disable:** `CRON_JOBS_ENABLED=0`

## Not migrated (intentional)

| Area | Reason |
|------|--------|
| Python sovereign loops | Already async-native; separate process |
| Kairo telemetry | Python `httpx`/stdlib — out of Node scope |
| Payments webhooks | Next.js route handlers — separate pass |
| Frontend `fetch` | Browser-native; sufficient for Arena polling |

## Follow-up

1. Migrate `src/app/payments` webhook handlers to shared axios retry helper (TypeScript)
2. Add `backend/src/jobs/cron.test.js` with mocked adapters
3. Wire sovereign SSE cache warming into cron

## Verify

```bash
cd backend && npm install && npm test && npm start
# Logs: [cron] started 3 background poll(s)
```
