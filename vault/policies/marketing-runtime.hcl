# Marketing runtime — Moltbook, Reddit, X, Email, Twilio campaign secrets
# Christopher's First App marketing namespace

path "yieldswarm/data/marketing/*" {
  capabilities = ["read"]
}

path "auth/approle/login" {
  capabilities = ["create", "update"]
}
