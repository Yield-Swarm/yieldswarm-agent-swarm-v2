# Odysseus YieldSwarm Workspace

Odysseus is the default human and agent workspace for YieldSwarm. It runs next
to the multi-LLM router, uses ChromaDB for persistent memory, and exposes one
authenticated UI for the 10,080 mutated agents and 169-deity council.

## Stack topology

```text
operator browser
  -> Odysseus web UI/API (:7000)
       -> built-in agent system
       -> ChromaDB memory (:8000 internal, :8100 optional host bind)
       -> SearXNG research (:8080 internal)
       -> ntfy task/reminder notifications (:8091 internal)
       -> LiteLLM router (:4000 internal)
            -> OpenRouter
            -> Fireworks
            -> Akash RTX 3090 Ollama workers
            -> local Ollama fallback
```

Only Odysseus should be exposed to operators, preferably behind Tailscale,
Cloudflare Access, or another trusted HTTPS/private-access layer. Keep ChromaDB,
SearXNG, ntfy, Ollama, and raw provider endpoints internal.

## Default model aliases

The compose stack mounts `config/litellm/config.yaml` into the LiteLLM router.
Use these aliases from Odysseus once the router is added as an OpenAI-compatible
provider:

| Alias | Backend |
| --- | --- |
| `yieldswarm-default` | OpenRouter model set by `OPENROUTER_MODEL` |
| `yieldswarm-fireworks` | Fireworks model set by `FIREWORKS_MODEL` |
| `akash-ollama` | Akash RTX 3090 Ollama endpoint set by `AKASH_OLLAMA_BASE_URL` |
| `akash-ollama-embed` | Ollama embedding model set by `AKASH_OLLAMA_EMBED_MODEL` |
| `local-ollama` | Host or compose-profile Ollama fallback |

Set `YIELDSWARM_ROUTER_API_KEY` and use it as the provider API key in Odysseus.
For local development the compose default is `yieldswarm-dev-router-key`; do not
use that default for shared or public deployments.

## Swarm memory bootstrap

The stack mounts `config/yieldswarm/` into Odysseus at:

```text
/app/data/imports/yieldswarm
```

On first boot:

1. Sign in to Odysseus.
2. Add the LiteLLM router in Settings as an OpenAI-compatible provider:
   - Base URL: `http://llm-router:4000/v1` from inside the Docker network, or
     `http://localhost:4000/v1` from the host.
   - API key: `YIELDSWARM_ROUTER_API_KEY`.
3. Import `swarm-manifest.json` and this document into Odysseus Memory.
4. Create agent presets for:
   - swarm operator;
   - shard auditor;
   - deity council facilitator;
   - Akash GPU worker coordinator;
   - revenue/yield monitor.

After import, Odysseus + ChromaDB become the persistent memory layer for swarm
decisions, model-routing context, shard operating notes, and council summaries.

## Akash RTX 3090 Ollama workers

Point the router at Akash Ollama workers with:

```env
AKASH_OLLAMA_BASE_URL=http://<akash-ollama-worker-host>:11434
AKASH_OLLAMA_HOSTS=<worker-a>:11434,<worker-b>:11434
AKASH_OLLAMA_MODEL=llama3.1:8b
AKASH_OLLAMA_EMBED_MODEL=nomic-embed-text
```

Ollama workers must listen on a routable interface, for example:

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

Protect those endpoints with the Akash private network, a WireGuard/Tailscale
overlay, or provider firewall rules. Do not expose unauthenticated Ollama
directly to the public internet.
