# Today's Task List — June 15, 2026

Prioritized parallel streams for the Cursor agent swarm and human operators.

## P0 — Do first (blocking revenue)

| # | Task | Owner | Effort | God Prompt / Command |
|---|------|-------|--------|----------------------|
| 1 | Merge `cursor/production-prep-9c82` + `cursor/god-prompt-swarm-9c82` to `main` | Human + Merge agent | 1–2h | Merge coordination prompt |
| 2 | Bootstrap Vault + seed secrets | Human (ops) | 30m | `make vault-bootstrap && make seed-vault` |
| 3 | Fund Akash wallet + first live lease | Human (ops) | 1h | `make deploy-akash` |
| 4 | Vercel production deploy | Human or Agent | 30m | `make deploy-vercel` |

## P1 — Parallel agent streams

| Stream | Task | Agent prompt | Branch |
|--------|------|--------------|--------|
| **A — MCP** | Load `.cursor/mcp.json` from top12 config | God Prompt Task 1 | `cursor/mcp-setup-9c82` |
| **B — Deploy** | Test `deploy-all.sh` dry-run on staging | God Prompt Task 2 | `cursor/production-prep-9c82` ✅ |
| **C — Reliability** | Axios + cron hardening (backend) | God Prompt Task 3 | `cursor/god-prompt-swarm-9c82` ✅ |
| **D — Akash** | Lease manager + Bittensor SDL live test | God Prompt Task 4 | `cursor/god-prompt-swarm-9c82` ✅ |
| **E — Funding** | Review `funding/` materials with counsel | God Prompt Task 5 | `cursor/god-prompt-swarm-9c82` ✅ |
| **F — Coordination** | Daily merge + readiness report | God Prompt Task 6 | This file |

## P2 — This week

| Task | Owner | Notes |
|------|-------|-------|
| Render blueprint connect | Human | `render.yaml` in dashboard |
| Azure `terraform/` apply | Agent | Needs Vault `providers/azure` |
| Stripe production keys | Human | Never in git |
| Close duplicate `cursor/*` PRs | Merge agent | See `MERGE_STRATEGY.md` |
| Sovereign loops live test | Agent | `make sovereign-up` |

## P3 — Backlog

- Terraform Cloud workspace `Helixchainprod` wiring
- Postgres payment persistence
- EVM Great Delta router MAINNET deploy
- Security audit on webhooks + Vault policies

## Human vs agent split

| Human only | Agent swarm |
|------------|-------------|
| Vault admin token, wallet mnemonics | Code, tests, docs, SDL renders |
| Stripe/Render/Vercel dashboard secrets | `deploy-all.sh --dry-run` |
| Investor meetings | `funding/` drafts |
| PR approval on `main` | Feature branches + CI fixes |

## Definition of done (today)

- [ ] `main` has production-prep + god-prompt-swarm merges
- [ ] Vault seeded with placeholder-free `.env`
- [ ] One Akash lease live with Vault injection
- [ ] Vercel staging URL serving Arena
- [ ] `TODAY_TASKS.md` updated tomorrow AM

See `SWARM_COORDINATION.md` for parallel agent rules.
