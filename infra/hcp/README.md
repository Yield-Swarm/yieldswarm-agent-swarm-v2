# HCP Quadrilateral — Operator Quick Start

Machine-readable inventory: [`quadrilateral-manifest.json`](quadrilateral-manifest.json)

## Four parallel tracks

| Track | Corner | Resource | Region |
|-------|--------|----------|--------|
| **A** | Secrets + Network | `vault-cluster` + `HCYSRL` | AWS Tokyo |
| **B** | Access + Failover net | `boundary-cluster` + `demo-hvn` | us-east-1 + Azure |
| **C** | Supply chain | Packer + Vagrant registries | Global |
| **D** | Orchestration | Terraform `Helixchainprod` | HCP |

## Commands

```bash
make hcp-quadrilateral-preflight   # verify CLI + manifest
make hcp-wire-quadrilateral        # dry-run wiring (default)
DRY_RUN=false make hcp-wire-quadrilateral
```

## Credit discipline ($500)

- One Vault cluster, one Boundary cluster — redundancy via **dual HVN**, not duplicate control planes.
- Packer registry avoids costly rebuild cycles.
- Terraform fallback modules scale to zero when Akash is healthy.

See [`docs/HCP_QUADRILATERAL_ARCHITECTURE.md`](../docs/HCP_QUADRILATERAL_ARCHITECTURE.md).
