# Mining Profitability Intelligence — June 2026

> Enterprise GPU fleet (H100 / H200 / B200) + Akash RTX 3090 + CPU RandomX

## TL;DR — most lucrative for our infra

| Priority | Coin | Algorithm | Best hardware | Est. $/day (single GPU) |
|----------|------|-----------|---------------|-------------------------|
| 1 | **KAS** (Kaspa) | kHeavyHash | H100/H200/B200, RTX 3090 | $0.9 – $3.50 |
| 2 | **QUBIC** | AI training lease | H100/H200/B200 only | $1.50 – $3.00 |
| 3 | **ALPH** (Alephium) | Blake3 | RTX 3090/4090, H100 | $0.7 – $1.40 |
| 4 | **XMR** (Monero) | RandomX | EPYC/Xeon CPU threads | $0.30 – $0.40 |
| 5 | **TAO** | Bittensor inference | Akash RTX 3090 | Variable (subnet) |
| 6 | **ETC** | Etchash | RTX 3090 | ~$0.50 |

**Do not mine KawPoW/Ravencoin on H100** — memory subsystem mismatch; use kHeavyHash or compute leases instead.

---

## Fleet hashpower (configured pods)

| Pod | GPU | Est. Kaspa | Est. XMR (CPU) |
|-----|-----|------------|----------------|
| thick_salmon_goat | H100 SXM | 2.6 GH/s | 22 KH/s |
| single_amber_peafowl | H200 SXM | 3.1 GH/s | 22 KH/s |
| outdoor_tomato_impala | B200 | 4.5 GH/s | 24 KH/s |
| **Fleet total** | 3× enterprise | **~10.2 GH/s** | **~68 KH/s** |

Live data: `python3 -m mining benchmark --json` or `GET /api/mining/benchmark`

---

## Free-credit strategy

| Platform | Credits | Deploy first |
|----------|---------|--------------|
| **Akash** | Wallet AKT | Bittensor + KAS on RTX 3090 SDL |
| **RunPod** | Promo credits | KAS GPU + XMR CPU + Qubic lease |
| **AWS/Azure** | $1k–2k | Grass nodes, burst training |
| **Vast.ai** | ~$500 | Overflow fine-tune when Akash saturated |

---

## Commands

```bash
# Research + estimates
python3 -m mining profitability --tier h100_sxm --json
python3 -m mining hashpower --json

# Hotload all
export MINING_DRY_RUN=0
./scripts/multiminer-hotload.sh

# RunPod only
./scripts/runpod_fleet_deploy.sh
./scripts/runpod_fleet_verify.sh
```

Config: `config/mining/coin-rankings.json`, `config/mining/runpod-fleet.json`

**Disclaimer:** Verify live on whattomine.com / NiceHash before routing payouts.
