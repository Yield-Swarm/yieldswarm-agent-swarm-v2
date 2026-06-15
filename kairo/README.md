# Kairo — Cryptographic Identity

Kairo lives in this repo (`/kairo`) alongside YieldSwarm for shared infra:

- **Domains:** `kairo.x`, `kairo.crypto` (see `DOMAINS.md`)
- **Akash:** GPU workers via `../akash/`
- **Secrets:** HashiCorp Vault via `../vault/`
- **Frontend:** Vercel deployment (shared or dedicated project)

## Status

Scaffold pending. Next PR will add:

- Mandelbrot identity pipeline
- Cryptographic key derivation UI
- Integration with YieldSwarm agent mesh

## Why same repo (for now)

Shared Vault policies, Akash SDL, Terraform fallback, and UD domain wiring.
Extract to `yieldswarm-kairo` when the UI stabilizes.
