# Quadrant IV Contracts

## GreatDeltaEmissionRouter

- File: `GreatDeltaEmissionRouter.sol`
- Split invariant (basis points):
  - Vault Treasury: 5000 (50%)
  - Operations Treasury: 3000 (30%)
  - Ecosystem Treasury: 1500 (15%)
  - Sovereign Reserve Treasury: 500 (5%)

### Deployment notes

1. Deploy with four non-zero treasury addresses.
2. Verify constructor args and ownership.
3. Route emissions by sending native token to `routeEmission()`.

### Audit checklist

- Ensure split constants sum to 10,000.
- Confirm treasury addresses are never zero-address.
- Confirm `routeEmission` cannot trap dust (remainder to sovereign reserve).
