# Odysseus orchestration layer — LLM keys, ChromaDB, agent mesh secrets.

path "yieldswarm/data/runtime/core"        { capabilities = ["read"] }
path "yieldswarm/data/runtime/llm"         { capabilities = ["read"] }
path "yieldswarm/data/runtime/odysseus"    { capabilities = ["read"] }
path "yieldswarm/data/integrations/*"      { capabilities = ["read"] }
path "yieldswarm/data/rpc/*"               { capabilities = ["read"] }

path "yieldswarm/metadata/runtime/*"       { capabilities = ["read","list"] }

path "auth/token/lookup-self"              { capabilities = ["read"] }
path "auth/token/renew-self"               { capabilities = ["update"] }
path "auth/token/revoke-self"              { capabilities = ["update"] }
