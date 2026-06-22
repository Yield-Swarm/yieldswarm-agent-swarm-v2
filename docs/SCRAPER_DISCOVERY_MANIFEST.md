# Scraper Discovery Manifest — DePIN / Multi-Mining Intelligence

Public GitHub metadata collection for the YieldSwarm multi-mining stack. **Read-only** — uses the GitHub REST API for repo metadata, issues, PRs, and (with `GITHUB_TOKEN`) code search. Does not exploit systems or bypass access controls.

## Manifest

`manifests/scraper-discovery-manifest.txt` — 20 targets across four categories:

| Category | Examples |
|----------|----------|
| DePIN / blockchain | `ton-org/ton-core`, `iotexproject/w3bstream`, `helium/helium-program` |
| Edge / routing | `basetenlabs/openclaw-baseten`, `neondatabase/serverless`, `colinhacks/zod` |
| Security research | `crytic/slither`, `immunefi-team/forge-safe`, `ton-blockchain/bug-bounty` |
| Serverless / tooling | `aws/serverless-application-model`, `pnpm/pnpm` |

**Environment preset** (embedded in manifest):

- Account context: `ethyswarm@proton.me`
- Routing tier: Singapore (`srv-d8sfuireo5us73efn3gg`)
- DB: Neon Serverless Postgres

## Run

```bash
# List parsed targets
python3 -m scraper_engine list

# Full discovery pass (matches your manifest execution string)
python3 -m scraper_engine run \
  --targets-file=manifests/scraper-discovery-manifest.txt \
  --output-bucket="yieldswarm-telemetry-singapore" \
  --depth=3 \
  --include-issues=true \
  --include-prs=true \
  --filter-keywords="rate-limit,token-leak,access-bypass,telemetry-skew,oidc-validation"

# Or via Makefile
make scraper-discovery
```

## Output

Results land under:

```
.run/scraper/yieldswarm-telemetry-singapore/
  discovery-<timestamp>.json
  latest.json
  manifest.snapshot.txt
```

Each target entry includes repo metadata; at depth ≥2, filtered issues/PRs; at depth 3 with `GITHUB_TOKEN`, code search hits.

## Auth

Optional but recommended for higher rate limits and code search:

```bash
export GITHUB_TOKEN=ghp_...   # from Vault integrations/github — never commit
```

## Depth levels

| Depth | Collects |
|-------|----------|
| 1 | Repo metadata (stars, default branch, open issues count) |
| 2 | + Issues and PRs matching filter keywords |
| 3 | + Code search snippets per keyword (requires token) |

## Integration

- Singapore gateway: `docs/NEXUS_MINER_DEPLOYMENT.md`
- Optional: pipe `latest.json` summaries into Neon via custom ETL (not auto-wired)

## Legal / ethics

Use only on **public** repositories and within GitHub API terms. For bug bounty work, follow each program's scope rules (Immunefi, TON bug-bounty, etc.). This tool indexes public signals — it does not perform unauthorized scanning.
