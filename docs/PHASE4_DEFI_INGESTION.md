# Phase 4: Cross-Chain DeFi Execution & Data Ingestion

Rust crate: `crates/yieldswarm-defi` (workspace root `Cargo.toml`).

> Repo `src/` is reserved for the Next.js app. See `src/defi/README.md` for the path map.

## Modules

| Module | Path | Role |
|--------|------|------|
| **Jupiter** | `defi::jupiter` | V6 quote + swap transaction build |
| **Orca** | `defi::orca` | Whirlpool CLMM liquidity provision |
| **Ingestion** | `ingestion` | tokio/reqwest alpha web crawler |

## Quick start

```bash
git checkout feature/04-defi-ingestion-layer
cargo build -p yieldswarm-defi
cargo test -p yieldswarm-defi
```

Requires **Rust 1.86+** (`rust-toolchain.toml`).

## Jupiter example

```rust
use yieldswarm_defi::defi::jupiter::JupiterRouteWrapper;

#[tokio::main]
async fn main() {
    let jup = JupiterRouteWrapper::new();
    let quote = jup.fetch_optimal_quote(
        "So11111111111111111111111111111111111111112",
        "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v",
        1_000_000,
        50,
        None,
    ).await.unwrap();
    println!("out: {}", quote.out_amount);
}
```

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `JUPITER_API_URL` | `https://quote-api.jup.ag/v6` | Quote/swap base |
| `JUPITER_API_KEY` | — | Optional x-api-key |
| `SOLANA_RPC_URL` | mainnet-beta | Orca RPC |
| `CROSS_CHAIN_DRY_RUN` | `1` | Orca simulate vs live |

Vault path: `yieldswarm/data/rpc/solana` (`jupiter_api_key`).

## Python parity

Existing MVP: `services/cross_chain/jupiter.py` — this Rust layer is the production swarm-engine path for Phase 4.

## Agent registry feed

```rust
use yieldswarm_defi::ingestion::{SwarmWebCrawler, IngestedPayload};
use tokio::sync::mpsc;

let (tx, mut rx) = mpsc::channel(32);
let crawler = SwarmWebCrawler::new(4);
crawler.execute_batch_crawl(vec!["https://example.com".into()], tx).await;
```

Payloads carry `data_hash` + `raw_content` sample for swarm_ops ingestion.
