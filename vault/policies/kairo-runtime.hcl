# Kairo driver app runtime — read-only access to identity and telemetry secrets.

path "yieldswarm/data/runtime/kairo"       { capabilities = ["read"] }
path "yieldswarm/data/runtime/wallets"     { capabilities = ["read"] }
path "yieldswarm/data/integrations/mapbox" { capabilities = ["read"] }
path "yieldswarm/data/integrations/stripe" { capabilities = ["read"] }
path "yieldswarm/data/integrations/iotex"  { capabilities = ["read"] }

path "yieldswarm/metadata/runtime/kairo"   { capabilities = ["read","list"] }

path "transit/encrypt/kairo-identity"      { capabilities = ["update"] }
path "transit/decrypt/kairo-identity"      { capabilities = ["update"] }
path "transit/sign/kairo-telemetry"        { capabilities = ["update"] }

path "auth/token/lookup-self"              { capabilities = ["read"] }
path "auth/token/renew-self"               { capabilities = ["update"] }
path "auth/token/revoke-self"              { capabilities = ["update"] }
