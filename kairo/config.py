"""Kairo bridge configuration."""

from __future__ import annotations

import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # API
    api_host: str = "0.0.0.0"
    api_port: int = 8090
    api_prefix: str = "/api/v1"

    # Database
    database_path: str = "kairo/data/kairo_bridge.db"

    # YieldSwarm integration
    yieldswarm_shard_count: int = 120
    mandelbrot_max_iter: int = 256
    tree_of_life_nodes: int = 10

    # Driver pay (2x logic)
    base_pay_rate_usd_per_km: float = 0.05
    driver_pay_multiplier_verified: float = 2.0
    min_signed_packets_for_2x: int = 10
    min_distance_km_for_2x: float = 5.0

    # DePIN reward estimates (USD per contribution point — illustrative)
    hnt_rate_per_point: float = 0.001
    grass_rate_per_point: float = 0.0008
    akt_rate_per_point: float = 0.0005

    # Payment rails
    wise_business_email: str = ""
    payout_wallet_evm: str = "0x9505578Bd5b32468E3cEa632664F7b8d2e46128c"

    # Vault (optional runtime — injected by Akash entrypoint)
    vault_addr: str = ""
    vault_role_id: str = ""
    vault_secret_id: str = ""

    # YieldSwarm harvest integration
    yieldswarm_harvest_dir: str = "/run/secrets/harvest"
    kairo_bridge_webhook_url: str = ""
    kairo_bridge_webhook_secret: str = ""
    kairo_api_signing_key: str = ""

    def apply_vault_env(self) -> None:
        """Load settings from Vault-injected environment variables."""
        if v := os.environ.get("WISE_BUSINESS_EMAIL"):
            self.wise_business_email = v
        if v := os.environ.get("KAIRO_WISE_PAYOUT_EMAIL"):
            self.wise_business_email = v
        if v := os.environ.get("KAIRO_BRIDGE_WEBHOOK_URL"):
            self.kairo_bridge_webhook_url = v
        if v := os.environ.get("KAIRO_BRIDGE_WEBHOOK_SECRET"):
            self.kairo_bridge_webhook_secret = v
        if v := os.environ.get("KAIRO_API_SIGNING_KEY"):
            self.kairo_api_signing_key = v
        if v := os.environ.get("YIELDSWARM_HARVEST_DIR"):
            self.yieldswarm_harvest_dir = v


settings = Settings()
settings.apply_vault_env()
