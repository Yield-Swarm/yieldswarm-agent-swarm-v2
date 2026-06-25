# LLM Council Consensus

All configured LLMs vote on the **next operational step** using a 14-Council quorum (9/14 approvals).

## Quick start

```bash
# List voters with API keys configured
python3 scripts/run-llm-consensus.py --list-voters

# Run consensus (gospel_sim works without keys)
python3 scripts/run-llm-consensus.py

# With your real-world report
python3 scripts/run-llm-consensus.py \
  --context-file docs/reports/my-real-world-stack.md \
  --options-json '[{"id":"a","label":"Deploy pillars"},{"id":"b","label":"Wire Tesla"}]'

# Via API (backend :8080)
curl -s -X POST http://127.0.0.1:8080/api/governance/llm-consensus/run \
  -H 'Content-Type: application/json' \
  -d '{
    "context": "Apollo Nexus hot load: XRP LTC TAO HYPE TON SOL USDC...",
    "options": [
      {"id": "trident", "label": "Trident mainnet", "detail": "npm run trident:deploy"},
      {"id": "mining", "label": "Mining tandem", "detail": "npm run mining:tandem"},
      {"id": "consensus", "label": "LLM council loop", "detail": "wire all voters"}
    ]
  }'
```

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/governance/llm-consensus/voters` | Active voters (keys present) |
| GET | `/api/governance/llm-consensus/last` | Last report from `.run/llm-consensus-report.json` |
| POST | `/api/governance/llm-consensus/run` | Run live vote |
| POST | `/api/governance/consensus/run` | Pass `mode: "llm"` or include `options` + `context` |

## Configure voters

Edit `config/governance/llm_voters.json`. Each voter maps to a **council seat** (1–14).

Set API keys in `.env` or Vault (`yieldswarm/data/runtime/llm`):

- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `GROQ_API_KEY`
- `LITELLM_URL` + `YIELDSWARM_ROUTER_API_KEY` (Odysseus router)
- `RTX5090_VLLM_BASE_URL` for Akash local inference

`gospel_sim` voter always runs (100-model gospel fallback) when live keys are missing.

## Response shape

```json
{
  "consensus": {
    "threshold": "9/14",
    "council_approvals": 10,
    "threshold_met": true,
    "winning_option_id": "trident",
    "winning_option_label": "Trident mainnet",
    "option_scores": { "trident": 4.2, "mining": 1.1 }
  },
  "live_voter_count": 3,
  "votes": [ { "voter_id": "openai-gpt4o", "vote": "approve", "chosen_option_id": "trident", ... } ]
}
```

## Share your real-world report

Save markdown or JSON to `docs/reports/real-world-stack.md` and run:

```bash
npm run consensus:llm -- --context-file docs/reports/real-world-stack.md
```

The council uses that file as context when voting on next steps.
