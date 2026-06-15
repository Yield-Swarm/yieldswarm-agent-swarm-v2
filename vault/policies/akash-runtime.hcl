# =========================================================================
# akash-runtime.hcl
# -------------------------------------------------------------------------
# Granted to the AppRole that Akash deployments use *at container start*
# via the Vault Agent sidecar / entrypoint. Reads only the secrets the
# in-container workload actually needs and is bound to the deployment's
# AppRole role_id (CIDR-pinned to Akash provider egress when possible).
# =========================================================================

# --- Workload-facing secrets --------------------------------------------
path "yieldswarm/data/akash/runtime" {
  capabilities = ["read"]
}

path "yieldswarm/data/runtime/+" {
  capabilities = ["read"]
}

# Per-shard agent fan-out (read only the shard your DSEQ owns)
path "yieldswarm/data/agents/shards/+" {
  capabilities = ["read"]
}

# RPC creds the on-Akash agent needs (helius, birdeye, jupiter, solana...)
path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

# LLM keys (Anthropic, OpenAI, Grok, Gemini) the agent uses for inference.
path "yieldswarm/data/llm/+" {
  capabilities = ["read"]
}

# --- Envelope encryption for any secret the workload must persist -------
path "transit/encrypt/agent-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/agent-runtime" {
  capabilities = ["update"]
}

# --- Token hygiene (renew + lookup self only) ---------------------------
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Hard deny on cloud-provider creds - Akash workloads must never see them.
path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
