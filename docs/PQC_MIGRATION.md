# Post-Quantum Cryptography Migration Guide

> NIST PQC hybrid rollout for YieldSwarm YSLR Layer 3.

## Standards

| Algorithm | NIST | YSLR usage |
|-----------|------|------------|
| ML-KEM-768 | FIPS 203 | Key encapsulation (hybrid with AES) |
| Falcon-512 | NIST round 3 | Telemetry + sovereign state signatures |
| Dilithium | FIPS 204 | Optional alternate sig (future) |

## Production requirements

```bash
# Ubuntu / Debian
sudo apt install liboqs-dev
pip install python-oqs

export KAIRO_REQUIRE_PQC=1
unset KAIRO_PQC_STUB
```

## Development stub

When `liboqs` is unavailable:

```bash
export KAIRO_PQC_STUB=1   # X25519 + SHA3 dev stub — NOT for production
```

Production with `KAIRO_PQC_STUB=1` is **blocked** when `NODE_ENV=production` or `KAIRO_REQUIRE_PQC=1`.

## Hybrid key rotation

| Epoch | Action |
|-------|--------|
| 0 | Generate PQC bundle at driver registration |
| 90d | Rotate via Vault; re-encrypt sovereign state |
| On compromise | Emergency rotate + `NETWORK_LOCKDOWN_MODE` |

Vault seed paths (add to `vault/scripts/seed-secrets.sh`):

```bash
vault kv put yieldswarm/runtime/pqc \
  kem_secret="$PQC_KEM_SECRET" \
  sig_secret="$PQC_SIG_SECRET"
```

## Lattice entropy (sovereign mutation)

`kairo/services/pqc.py::lattice_entropy()` feeds Iteration-100 agent mutation loops and Helix `entropy-core` pulses.

```python
from kairo.services.yslr import sovereign_mutation_seed
seed = sovereign_mutation_seed("loop-100", iteration=42)
```

## Side-channel resistance

- `hmac.compare_digest` for all MAC/signature comparisons
- No secret logging; Vault-only key material
- Constant-time paths in `pqc_verify`

## Benchmarks (Akash RTX)

Run on GPU workers before MAINNET:

```bash
python3 -m pytest tests/test_yslr.py -v --durations=10
# Target: <50ms encrypt/decrypt per telemetry batch on CPU
```

## Crypto-agility

Env `YSLR_PQC_KEM_ALG` / `YSLR_PQC_SIG_ALG` reserved for algorithm migration without code changes (future).

## Audit checklist

- [ ] `python-oqs` on all production nodes
- [ ] `KAIRO_PQC_STUB` unset in MAINNET
- [ ] Vault paths seeded; no keys in `.env`
- [ ] Orchard circuits formally verified
- [ ] `tests/test_yslr.py` green in CI
- [ ] SECRETS_AUDIT.md updated
