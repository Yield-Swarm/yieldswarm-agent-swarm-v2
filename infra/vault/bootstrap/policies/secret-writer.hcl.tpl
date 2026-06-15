# Assign this policy only to trusted operators or a dedicated break-glass role
# responsible for loading and rotating secret values.

path "${kv_mount}/data/cloud/*" {
  capabilities = ["create", "update", "read", "delete"]
}

path "${kv_mount}/data/rpc/*" {
  capabilities = ["create", "update", "read", "delete"]
}

path "${kv_mount}/data/app/*" {
  capabilities = ["create", "update", "read", "delete"]
}

path "${kv_mount}/metadata/cloud/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "${kv_mount}/metadata/rpc/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "${kv_mount}/metadata/app/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}

path "${kv_mount}/delete/cloud/*" {
  capabilities = ["update"]
}

path "${kv_mount}/delete/rpc/*" {
  capabilities = ["update"]
}

path "${kv_mount}/delete/app/*" {
  capabilities = ["update"]
}

path "${kv_mount}/undelete/cloud/*" {
  capabilities = ["update"]
}

path "${kv_mount}/undelete/rpc/*" {
  capabilities = ["update"]
}

path "${kv_mount}/undelete/app/*" {
  capabilities = ["update"]
}

path "${kv_mount}/destroy/cloud/*" {
  capabilities = ["update"]
}

path "${kv_mount}/destroy/rpc/*" {
  capabilities = ["update"]
}

path "${kv_mount}/destroy/app/*" {
  capabilities = ["update"]
}

path "${kv_mount}/metadata/cloud" {
  capabilities = ["list"]
}

path "${kv_mount}/metadata/rpc" {
  capabilities = ["list"]
}

path "${kv_mount}/metadata/app" {
  capabilities = ["list"]
}
