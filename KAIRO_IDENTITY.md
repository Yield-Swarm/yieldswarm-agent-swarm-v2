# Kairo Driver Identity

Persistent **IoTeX + EVM** compatible addresses for every Kairo driver.

## Features

- BIP39 12-word mnemonic at registration (shown once)
- BIP44 path `m/44'/60'/0'/0/0` — same key material for EVM (`0x…`) and IoTeX (`io1…` Bech32)
- AES-GCM encrypted private key at rest (`KAIRO_IDENTITY_ENCRYPTION_KEY`)
- Optional scrypt-encrypted mnemonic backup (`recovery_passphrase`)
- HashiCorp Vault mirror at `yieldswarm/kairo/drivers/{driver_id}`

## Register

```bash
curl -s -X POST http://localhost:8091/api/drivers \
  -H 'Content-Type: application/json' \
  -d '{"driver_id":"driver-1","recovery_passphrase":"your-recovery-secret"}'
```

Response includes `mnemonic` **once** — store offline.

## Recover

```bash
curl -s -X POST http://localhost:8091/api/drivers/recover \
  -H 'Content-Type: application/json' \
  -d '{
    "mnemonic": "word1 word2 ... word12",
    "driver_id": "driver-1",
    "recovery_passphrase": "your-recovery-secret"
  }'
```

## Local storage

```
.data/kairo/
  drivers.json              # public index
  wallets/{driver_id}.json  # encrypted keys (mode 0600)
```

## Vault

```bash
vault kv put yieldswarm/kairo/drivers/driver-1 \
  private_key="..." mnemonic="..." derivation_path="m/44'/60'/0'/0/0"
```

Policy: `vault/policies/kairo-runtime.hcl`

## YSLR encryption (Layer 1–3)

Driver registration now includes `yslr_keys` in the response — Orchard viewing key fingerprints + PQC public material.

| Layer | Technology |
|-------|------------|
| L1 | AES-256-GCM + HKDF |
| L2 | Orchard-style shielded keys + ZK telemetry proofs |
| L3 | ML-KEM-768 + Falcon-512 hybrid |

```bash
# Encrypt telemetry batch
curl -s -X POST http://localhost:8080/api/yslr/telemetry \
  -H 'Content-Type: application/json' \
  -d '{"driver_id":"driver-1","samples":[{"speed_kmh":40}]}'
```

See `docs/YSLR.md` and `docs/PQC_MIGRATION.md`.
