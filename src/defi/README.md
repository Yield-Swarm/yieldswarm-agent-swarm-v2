# Phase 4 — DeFi & Ingestion (Rust)

Rust implementation lives in **`crates/yieldswarm-defi/`** because repo root `src/` is the Next.js app.

```
crates/yieldswarm-defi/src/
├── lib.rs              # pub mod defi { jupiter, orca }; pub mod ingestion;
├── defi/
│   ├── jupiter/mod.rs  # Jupiter V6 routing wrapper
│   └── orca/mod.rs     # Orca Whirlpool CLMM client
└── ingestion/mod.rs    # tokio + reqwest alpha crawler
```

## Build

```bash
cargo build -p yieldswarm-defi
cargo test -p yieldswarm-defi
```

## Env

| Variable | Module |
|----------|--------|
| `JUPITER_API_URL` | Jupiter base (default `https://quote-api.jup.ag/v6`) |
| `JUPITER_API_KEY` | Optional API key header |
| `SOLANA_RPC_URL` | Orca client RPC |
| `CROSS_CHAIN_DRY_RUN` | Orca simulate vs live (default dry) |
