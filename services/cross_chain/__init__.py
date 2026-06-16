"""YieldSwarm cross-chain execution layer.

Strategies: Uniswap V4 hooks, Solana DEX (Jupiter/Orca/Raydium), dYdX perps, altcoin PoW.
All revenue routes through Great Delta 50/30/15/5 before settlement.
"""

from services.cross_chain.executor import CrossChainExecutor, run_scheduled_strategies
from services.cross_chain.great_delta import route_revenue_to_treasury

__all__ = [
    "CrossChainExecutor",
    "run_scheduled_strategies",
    "route_revenue_to_treasury",
]
