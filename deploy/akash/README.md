# Odysseus Akash Deployment

`odysseus.sdl.yml` defines the Odysseus GPU workload for Akash.

## Resource profile

- CPU: 8 units
- Memory: 32 GiB
- GPU: 1 NVIDIA H100, A100, or RTX 4090 class device
- Storage: 80 GiB
- HTTP: container port 8080 exposed globally as port 80

## Vault contract

The SDL does not contain Odysseus API keys, model hosts, model API keys, wallet
material, or provider credentials. It only passes Vault connection coordinates to
the container. At startup, `entrypoint-odysseus.sh` reads:

- `ODYSSEUS_API_KEY`
- `ODYSSEUS_MODEL_HOST`
- `ODYSSEUS_MODEL_API_KEY`

from `ODYSSEUS_RUNTIME_VAULT_PATH` in HashiCorp Vault. Additional runtime values
stored at the same Vault path are exported into the process environment if their
keys are valid environment variable names.

Render and submit the SDL with `scripts/deploy-production-odysseus.sh`; the
script supplies defaults and keeps secrets in Vault.
