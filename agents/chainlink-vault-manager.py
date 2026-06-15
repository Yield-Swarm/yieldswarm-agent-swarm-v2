# Chainlink Vault Manager Agent
# Receives funds from Antminer Z15 sales + other revenue
# Stores in secure Chainlink-integrated vault
# YieldSwarm agents optimize capital across DePIN (Akash, Grass) and yield strategies
# Part of MEGA TASK Hydrogen Particle scaling

from runtime_config import require_env


require_env(
    [
        "AGENTSWARM_MASTER_KEY",
        "PRIMARY_RPC_URL",
        "WALLET_ENCRYPTION_KEY",
        "TEE_SIGNING_KEY",
        "CHAINLINK_VAULT_ADDRESS",
    ]
)

print("Chainlink Vault Manager active - Vault runtime configuration loaded")