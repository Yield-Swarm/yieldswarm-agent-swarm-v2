# Payment rails — Stripe, Square, Wise webhook secrets.

path "yieldswarm/data/runtime/payments"    { capabilities = ["read"] }
path "yieldswarm/data/integrations/stripe" { capabilities = ["read"] }
path "yieldswarm/data/integrations/square" { capabilities = ["read"] }
path "yieldswarm/data/integrations/wise"   { capabilities = ["read"] }

path "yieldswarm/metadata/runtime/payments" { capabilities = ["read","list"] }

path "auth/token/lookup-self"              { capabilities = ["read"] }
path "auth/token/renew-self"               { capabilities = ["update"] }
path "auth/token/revoke-self"              { capabilities = ["update"] }
