"""Mining reward routing — coin payouts to funded treasury wallets."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from services.cross_chain.great_delta import route_revenue_to_treasury


@dataclass(frozen=True)
class WalletRoute:
    coin: str
    wallet: str
    source_env: str
    chain: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "coin": self.coin,
            "wallet": self.wallet,
            "source_env": self.source_env,
            "chain": self.chain,
        }


# Priority-ordered env keys per payout asset
WALLET_ENV_PRIORITY: Dict[str, List[tuple[str, str]]] = {
    "tao": [("MINING_ROOT_TAO", "bittensor"), ("TAO_WALLET_ADDRESS", "bittensor"), ("BITTENSOR_COLDKEY_ADDRESS", "bittensor")],
    "bittensor": [("MINING_ROOT_TAO", "bittensor"), ("TAO_WALLET_ADDRESS", "bittensor")],
    "sol": [("NEXUS_TREASURY_SOLANA", "solana"), ("TREASURY_ADDRESS", "solana"), ("MINING_ROOT_PRL", "solana")],
    "solana": [("NEXUS_TREASURY_SOLANA", "solana"), ("TREASURY_ADDRESS", "solana")],
    "etc": [("MINING_ROOT_BASE_ETC", "ethereum"), ("ETC_WALLET_ADDRESS", "ethereum")],
    "xmr": [("MONERO_WALLET_ADDRESS", "monero"), ("MINING_ROOT_MONERO", "monero"), ("XMR_WALLET_ADDRESS", "monero")],
    "monero": [("MONERO_WALLET_ADDRESS", "monero")],
    "zec": [("MINING_ROOT_ZEC", "zcash"), ("ZEC_SHIELDED_KEY", "zcash")],
    "prl": [("MINING_ROOT_PRL", "solana"), ("MINING_WALLET_PRL", "solana")],
    "krx": [("MINING_WALLET_KRX", "blockdag")],
    "zano": [("MINING_WALLET_ZANO", "zano")],
    "qtc": [("MINING_WALLET_QTC", "qitcoin")],
    "iron": [("MINING_WALLET_IRON", "ironfish")],
    "ton": [("MINING_WALLET_TON", "ton"), ("TREASURY_TON_ADDRESS", "ton")],
    "grass": [("GRASS_PAYOUT_WALLET", "solana")],
    "helium": [("HELIUM_PAYOUT_WALLET", "iotex"), ("IOTEX_TREASURY", "iotex")],
    "iotex": [("IOTEX_TREASURY", "iotex"), ("MINING_ROOT_IOTEX", "iotex")],
    "btc": [("MINING_ROOT_BASE_BTC", "bitcoin"), ("IOTEX_BTC_BRIDGE", "bitcoin")],
}


class RewardRouter:
    """Resolve payout destinations and apply Great Delta treasury overlay."""

    def __init__(self) -> None:
        self._routes = self._build_routes()

    def _resolve_env(self, env_keys: List[tuple[str, str]]) -> Optional[WalletRoute]:
        for env_key, chain in env_keys:
            value = os.getenv(env_key, "").strip()
            if value and value not in ("[REDACTED]", ""):
                coin = env_key.lower().replace("mining_root_", "").replace("_wallet_address", "")
                return WalletRoute(coin=coin, wallet=value, source_env=env_key, chain=chain)
        return None

    def _build_routes(self) -> Dict[str, WalletRoute]:
        routes: Dict[str, WalletRoute] = {}
        for coin, env_list in WALLET_ENV_PRIORITY.items():
            route = self._resolve_env(env_list)
            if route:
                routes[coin] = route
        return routes

    def get_wallet(self, coin: str) -> Optional[str]:
        route = self._routes.get(coin.lower())
        return route.wallet if route else None

    def route_table(self) -> Dict[str, Any]:
        return {
            "routes": {k: v.to_dict() for k, v in self._routes.items()},
            "configured_count": len(self._routes),
        }

    def apply_to_miner_config(self, miner_name: str, config: Dict[str, Any]) -> Dict[str, Any]:
        """Inject payout wallet into generated miner config."""
        mapping = {
            "bittensor": "tao",
            "monero": "xmr",
            "etc": "etc",
            "grass": "grass",
            "helium": "helium",
            "prl": "prl",
            "krx": "krx",
            "zano": "zano",
            "qtc": "qtc",
            "iron": "iron",
            "ton": "ton",
        }
        coin = mapping.get(miner_name, miner_name)
        wallet = self.get_wallet(coin)
        if wallet:
            config["payout_wallet"] = wallet
            config["payout_coin"] = coin
        return config

    def route_mining_revenue(
        self,
        amount_usd: float,
        *,
        source: str,
        coin: str,
        apply_treasury_split: bool = True,
    ) -> Dict[str, Any]:
        wallet = self.get_wallet(coin)
        result: Dict[str, Any] = {
            "coin": coin,
            "source": source,
            "amount_usd": amount_usd,
            "payout_wallet": wallet,
            "routed": bool(wallet),
        }
        if apply_treasury_split and amount_usd > 0:
            result["treasury_split"] = route_revenue_to_treasury(amount_usd, source=source, strategy=coin)
        return result
