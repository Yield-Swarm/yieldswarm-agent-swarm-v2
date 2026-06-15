# =========================================================================
# agent-runtime.hcl
# -------------------------------------------------------------------------
# Granted to on-prem / Vercel / Azure agent shards (NOT the Akash ones,
# those use akash-runtime.hcl above). Identical secret reach to
# akash-runtime, but pinned to a different AppRole with longer token
# TTL since these run on long-lived nodes with persistent disks.
# =========================================================================

path "yieldswarm/data/agents/shards/+" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

path "yieldswarm/data/llm/+" {
  capabilities = ["read"]
}

path "yieldswarm/data/integrations/+" {
  capabilities = ["read"]
}

path "transit/encrypt/agent-runtime" {
  capabilities = ["update"]
}
path "transit/decrypt/agent-runtime" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "yieldswarm/data/cloud/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
