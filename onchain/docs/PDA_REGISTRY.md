# PDA Registry — YieldSwarm On-Chain Programs

> Single source of truth for seeds. **Do not collide across programs.**

| Program | Account | Seeds | Bump stored |
|---------|---------|-------|-------------|
| yield_vault | VaultState | `["vault_state", treasury_pubkey]` | yes |
| yield_vault | VaultAuthority | `["vault_authority"]` | yes |
| bonding_curve | BondingCurveState | `["bonding_curve", mint]` | yes |
| bonding_curve | ReferralRegistry | `["referral_registry"]` | yes |
| bonding_curve | LiquidityLock | `["liquidity_lock", mint]` | yes |
| swarm_ops | AgentPermissionRegistry | `["agent_registry", agent_pubkey]` | yes |
| swarm_ops | StrategyProposal | `["proposal", proposal_id]` | yes |
| coordinator | ShardVault | `["shard_vault", shard_id]` | yes |
| security | AgentRegistry | `["security_agent", agent_pubkey]` | yes |
| cross_chain | BridgeState | `["bridge_state"]` | yes |

Instance A owns yield_vault, bonding_curve, security seeds.  
Instance B owns cross_chain, swarm_ops, coordinator seeds.
