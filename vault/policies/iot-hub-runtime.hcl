# =========================================================================
# iot-hub-runtime.hcl — IoT Hub (FWA_37KN9S-IoT) home network devices
# -------------------------------------------------------------------------
# Granted to IoT Hub workers on the LAN or Akash telemetry sidecars.
# Reads device catalog secrets and network config; denies cloud operator creds.
# =========================================================================

path "yieldswarm/data/iot/devices" {
  capabilities = ["read"]
}
path "yieldswarm/data/iot/network" {
  capabilities = ["read"]
}
path "yieldswarm/data/runtime/core" {
  capabilities = ["read"]
}
path "yieldswarm/data/integrations/smartthings" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/solana" {
  capabilities = ["read"]
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
path "yieldswarm/data/providers/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/runtime/wallets" {
  capabilities = ["deny"]
}
