"""Cross-chain strategy implementations."""

from services.cross_chain.strategies.altcoin_pow import AltcoinPowStrategy
from services.cross_chain.strategies.dydx_perps import DydxPerpsStrategy
from services.cross_chain.strategies.solana_liquidity import SolanaLiquidityStrategy
from services.cross_chain.strategies.stellar_cosmos import StellarCosmosStrategy
from services.cross_chain.strategies.uniswap_v4 import UniswapV4HookStrategy

STRATEGY_REGISTRY = {
    "uniswap_v4_hook": UniswapV4HookStrategy,
    "solana_liquidity": SolanaLiquidityStrategy,
    "dydx_perps": DydxPerpsStrategy,
    "altcoin_pow": AltcoinPowStrategy,
    "stellar_cosmos": StellarCosmosStrategy,
}

__all__ = [
    "STRATEGY_REGISTRY",
    "UniswapV4HookStrategy",
    "SolanaLiquidityStrategy",
    "DydxPerpsStrategy",
    "AltcoinPowStrategy",
    "StellarCosmosStrategy",
]
