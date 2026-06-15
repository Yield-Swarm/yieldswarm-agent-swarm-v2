# OpenClaw scaling reads orchestration, LLM, and cloud burst credentials only.
path "secret/data/yieldswarm/core" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/llm" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/cloud/runpod" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/cloud/vultr" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/cloud/digitalocean" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}
