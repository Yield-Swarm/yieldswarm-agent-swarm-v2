from mining.miners.base import BaseMiner, MinerState, MinerStatus
from mining.miners.bittensor_miner import BittensorMiner
from mining.miners.monero_miner import MoneroMiner
from mining.miners.etc_miner import EthereumClassicMiner
from mining.miners.grass_miner import GrassMiner
from mining.miners.helium_miner import HeliumMiner
from mining.miners.kaspa_miner import KaspaMiner
from mining.miners.qubic_miner import QubicMiner

MINER_REGISTRY = {
    "bittensor": BittensorMiner,
    "monero": MoneroMiner,
    "etc": EthereumClassicMiner,
    "grass": GrassMiner,
    "helium": HeliumMiner,
    "kaspa": KaspaMiner,
    "qubic": QubicMiner,
}

__all__ = [
    "BaseMiner",
    "MinerState",
    "MinerStatus",
    "BittensorMiner",
    "MoneroMiner",
    "EthereumClassicMiner",
    "GrassMiner",
    "HeliumMiner",
    "KaspaMiner",
    "QubicMiner",
    "MINER_REGISTRY",
]
