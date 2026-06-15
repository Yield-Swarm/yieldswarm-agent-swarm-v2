# vault/policies/admin.hcl
# Break-glass / platform operator. Grant only to a hardware-token backed user.
# Do NOT assign to humans by default — use for initial bootstrap and rotation only.

# Manage policies, mounts, auth methods, audit devices.
path "sys/policies/acl/*"       { capabilities = ["create","read","update","delete","list"] }
path "sys/mounts"               { capabilities = ["read","list"] }
path "sys/mounts/*"             { capabilities = ["create","read","update","delete","list","sudo"] }
path "sys/auth"                 { capabilities = ["read","list"] }
path "sys/auth/*"               { capabilities = ["create","read","update","delete","list","sudo"] }
path "sys/audit"                { capabilities = ["read","list"] }
path "sys/audit/*"              { capabilities = ["create","read","update","delete","list","sudo"] }
path "sys/leases/*"             { capabilities = ["create","read","update","delete","list","sudo"] }

# Manage AppRole roles and rotate secret IDs.
path "auth/approle/role"        { capabilities = ["list"] }
path "auth/approle/role/*"      { capabilities = ["create","read","update","delete","list"] }

# Full access to KV v2 namespaces used by this platform.
path "yieldswarm/*"             { capabilities = ["create","read","update","delete","list","sudo"] }

# Manage transit keys (envelope encryption / wallet signing).
path "transit/*"                { capabilities = ["create","read","update","delete","list","sudo"] }

# Health / capabilities self-check.
path "sys/health"               { capabilities = ["read","sudo"] }
path "sys/capabilities-self"    { capabilities = ["update"] }
