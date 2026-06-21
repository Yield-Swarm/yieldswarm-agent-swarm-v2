"""Node 5 configuration — secrets from env / Vault (SecretProd.pdf → never commit)."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import List, Optional


def _bool(value: Optional[str], default: bool = False) -> bool:
    if value is None or value == "":
        return default
    return value.lower() in ("1", "true", "yes", "on")


@dataclass
class StellarConfig:
    """Stellar (XLM) SDK settings — map from SecretProd.pdf via Vault."""

    enabled: bool = False
    network: str = "public"  # public | testnet
    horizon_url: str = "https://horizon.stellar.org"
    secret_key: str = ""
    public_key: str = ""
    destination: str = ""  # default treasury / payout address
    base_asset: str = "XLM"

    @property
    def configured(self) -> bool:
        return bool(self.secret_key and self.public_key)

    def redacted(self) -> dict:
        return {
            "enabled": self.enabled,
            "network": self.network,
            "horizon_url": self.horizon_url,
            "public_key": self.public_key,
            "destination": self.destination,
            "base_asset": self.base_asset,
            "secret_configured": bool(self.secret_key),
        }


@dataclass
class CosmosConfig:
    """Cosmos SDK chain settings (Akash, IoTeX hub, custom REST)."""

    enabled: bool = False
    chain_id: str = "akashnet-2"
    rest_url: str = "https://rest.cosmos.directory/akash"
    address: str = ""
    mnemonic: str = ""
    gas_price: str = "0.025uakt"
    denom: str = "uakt"

    @property
    def configured(self) -> bool:
        return bool(self.address or self.mnemonic)

    def redacted(self) -> dict:
        return {
            "enabled": self.enabled,
            "chain_id": self.chain_id,
            "rest_url": self.rest_url,
            "address": self.address,
            "denom": self.denom,
            "mnemonic_configured": bool(self.mnemonic),
        }


@dataclass
class Node5Config:
    """Unified Node 5 module configuration."""

    enabled: bool = True
    dry_run: bool = True
    stellar: StellarConfig = field(default_factory=StellarConfig)
    cosmos: CosmosConfig = field(default_factory=CosmosConfig)
    actions: List[str] = field(default_factory=lambda: ["status", "balance"])

    def redacted(self) -> dict:
        return {
            "enabled": self.enabled,
            "dry_run": self.dry_run,
            "actions": self.actions,
            "stellar": self.stellar.redacted(),
            "cosmos": self.cosmos.redacted(),
        }


def load_node5_config() -> Node5Config:
    """
    Load Node 5 config from environment.

    SecretProd.pdf keys (inject via Vault, never commit):
      STELLAR_SECRET_KEY, STELLAR_PUBLIC_KEY, STELLAR_DESTINATION_ADDRESS
      COSMOS_MNEMONIC, COSMOS_ADDRESS, COSMOS_CHAIN_ID, COSMOS_REST_URL
    """
    network = os.getenv("STELLAR_NETWORK", "public").lower()
    horizon = os.getenv(
        "STELLAR_HORIZON_URL",
        "https://horizon-testnet.stellar.org"
        if network == "testnet"
        else "https://horizon.stellar.org",
    )

    stellar = StellarConfig(
        enabled=_bool(os.getenv("NODE5_STELLAR_ENABLED"), True),
        network=network,
        horizon_url=horizon.rstrip("/"),
        secret_key=os.getenv("STELLAR_SECRET_KEY", os.getenv("STELLAR_SIGNER_SECRET", "")),
        public_key=os.getenv("STELLAR_PUBLIC_KEY", os.getenv("STELLAR_ACCOUNT_ID", "")),
        destination=os.getenv(
            "STELLAR_DESTINATION_ADDRESS",
            os.getenv("NEXUS_TREASURY_STELLAR", ""),
        ),
        base_asset=os.getenv("STELLAR_BASE_ASSET", "XLM"),
    )

    cosmos = CosmosConfig(
        enabled=_bool(os.getenv("NODE5_COSMOS_ENABLED"), True),
        chain_id=os.getenv("COSMOS_CHAIN_ID", os.getenv("AKASH_CHAIN_ID", "akashnet-2")),
        rest_url=os.getenv(
            "COSMOS_REST_URL",
            os.getenv("AKASH_REST_URL", "https://rest.cosmos.directory/akash"),
        ).rstrip("/"),
        address=os.getenv("COSMOS_ADDRESS", os.getenv("AKASH_OWNER_ADDRESS", "")),
        mnemonic=os.getenv("COSMOS_MNEMONIC", os.getenv("AKASH_WALLET_MNEMONIC", "")),
        gas_price=os.getenv("COSMOS_GAS_PRICE", "0.025uakt"),
        denom=os.getenv("COSMOS_DENOM", "uakt"),
    )

    actions_raw = os.getenv("NODE5_ACTIONS", "status,balance")
    actions = [a.strip() for a in actions_raw.split(",") if a.strip()]

    return Node5Config(
        enabled=_bool(os.getenv("NODE5_ENABLED"), True),
        dry_run=_bool(os.getenv("NODE5_DRY_RUN", os.getenv("CROSS_CHAIN_DRY_RUN", "1")), True),
        stellar=stellar,
        cosmos=cosmos,
        actions=actions,
    )
