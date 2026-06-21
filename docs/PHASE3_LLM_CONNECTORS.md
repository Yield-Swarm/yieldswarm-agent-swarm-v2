# Phase 3 — Multi-LLM Routing Connectors

Bridges the Rust connector crate with the TypeScript / Next.js stack.

## Layout

| Path | Role |
|------|------|
| `crates/llm-connectors/src/connectors/gemini/` | Gemini structured JSON (schema-constrained yield strategies) |
| `crates/llm-connectors/src/connectors/grok/` | SuperGrok / xAI real-time market intel |
| `crates/llm-connectors/src/connectors/kimi/` | Kimi Claw scheduled task automation |
| `src/lib/llm/connectors/` | TypeScript mirror + `routeLlmRequest()` |
| `src/app/api/llm/route/` | HTTP dispatch for swarm coordinator |

> User spec referenced `src/connectors/`; Rust lives under `crates/llm-connectors/src/connectors/` to avoid colliding with the Next.js `src/` tree.

## Build

```bash
cargo check -p llm-connectors
```

## Environment

| Variable | Connector |
|----------|-----------|
| `GEMINI_API_KEY` | Gemini |
| `GEMINI_MODEL` | Optional (default `gemini-2.5-pro`) |
| `GROK_API_KEY` / `XAI_API_KEY` | SuperGrok |
| `GROK_MODEL` | Optional (default `grok-2-latest`) |
| `GROK_API_BASE` | Optional xAI endpoint |
| `KIMICLAW_CONSENSUS_KEY` / `KIMI_CLAW_API_TOKEN` | Kimi Claw |
| `KIMI_CLAW_API_BASE` | Optional Claw API base |

## API

```bash
curl -s -X POST http://localhost:3000/api/llm/route \
  -H 'Content-Type: application/json' \
  -d '{"connector":"gemini","prompt":"Propose 3 yield allocations for SOL staking."}'
```

## Vault

Seed keys under `yieldswarm/data/llm/gemini`, `yieldswarm/data/llm/grok` (see `akash/templates/runtime.env.ctmpl`).
