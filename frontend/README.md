# YieldSwarm v2 Frontend — Unified Wallet Layer

A production-grade, custom multi-chain wallet connection system (in the spirit of
RainbowKit, but built in-house and chain-agnostic). It is the **default wallet
layer used everywhere in the frontend** — Arena, Portal and Payments all consume
the same `@/wallet` package.

## Supported ecosystems

| Ecosystem | Library                       | Connect | Balance | Sign msg | Native transfer | Token |
| --------- | ----------------------------- | ------- | ------- | -------- | --------------- | ----- |
| EVM       | `viem` + `@wagmi/core`        | ✅      | ✅      | ✅       | ✅              | ERC-20 ✅ |
| Solana    | `@solana/web3.js`             | ✅      | ✅ (SOL + SPL read) | ✅ | ✅           | SPL read-only |
| TON       | `@tonconnect/sdk`             | ✅      | ✅      | ton_proof | ✅            | — |
| Bitcoin   | injected (UniSat/OKX/ME)      | ✅      | ✅      | ✅       | ✅              | — |

## Features

- **Multi-wallet connect modal** — one modal, grouped by ecosystem, with live
  install detection and download deep-links. (`<ConnectModal/>`, auto-mounted.)
- **Balance fetching across chains** — `useBalance()` with polling + an
  aggregated portfolio view in Portal.
- **Transaction signing for deposits/withdrawals** — `useTransfer()` powers the
  Payments deposit/withdraw flows for every chain through one API.
- **Auto-detection of the connected chain** — adapters report the active chain
  and react to wallet `chainChanged` / `accountChanged` events. EVM chains are
  switchable from the account menu.
- **Silent auto-reconnect** — the last session per ecosystem is restored on load.
- **Multiple simultaneous connections** — connect e.g. an EVM wallet *and* a
  Solana wallet at once; one "active" namespace drives defaults.

## Architecture

```
src/wallet/
  types.ts            # ecosystem-agnostic types + ChainAdapter contract
  chains.ts           # chain registry (ids like "evm:1", "solana:mainnet")
  config.ts           # env-driven RPC / project config
  format.ts           # base-unit <-> human formatting helpers
  manager.ts          # WalletManager: multiplexes all adapters into one API
  adapters/
    evm.ts            # wagmi/core + viem
    solana.ts         # @solana/web3.js + injected provider
    ton.ts            # @tonconnect/sdk
    bitcoin.ts        # injected UniSat-style providers
  react/
    WalletProvider.tsx, context.ts, hooks.ts
  ui/
    ConnectModal.tsx, AccountModal.tsx, WalletButton.tsx, BalanceLine.tsx
  index.ts            # public API
```

Each ecosystem implements the same `ChainAdapter` interface. `WalletManager`
owns one adapter per ecosystem, merges their event streams into a single
observable snapshot, and exposes one imperative API. The React layer
(`WalletProvider` + hooks) is just a consumer of the manager.

## Usage

```tsx
import { WalletProvider, WalletButton, useWallet, useBalance, useTransfer } from "@/wallet";

// 1. Wrap the app once
<WalletProvider>
  <App />
</WalletProvider>;

// 2. Drop the button in your nav
<WalletButton />;

// 3. Use hooks anywhere
const { activeAccount, isConnected, openConnectModal } = useWallet();
const { data: balance } = useBalance();
const { send, status } = useTransfer();
await send({ to: treasury, amount: "0.5" }); // active chain
```

## Getting started

```bash
cd frontend
npm install
cp .env.example .env   # optional; public defaults work out of the box
npm run dev            # http://localhost:5173
npm run build          # typecheck + production build
```

## Configuration

All config is via `VITE_*` env vars — see `.env.example`. The most impactful is
`VITE_WALLETCONNECT_PROJECT_ID`, which unlocks QR/mobile EVM wallets. For
production, point the RPC vars at dedicated endpoints (public RPCs are
rate-limited).

## Notes & scope

- SPL-token and Jetton **transfers** are intentionally out of scope for this base
  ("basic Bitcoin", read-only token balances). Native transfers work on all four
  ecosystems; ERC-20 transfers work on EVM. The adapter interface is ready for
  token-send extensions.
- TonConnect returns a signed BOC rather than a tx hash; the BOC is surfaced as
  the result identifier (resolve to a hash via an indexer if needed).
- Replace `public/tonconnect-manifest.json` and the Payments treasury addresses
  with your production values.
