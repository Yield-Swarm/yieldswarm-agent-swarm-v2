"""14 structural book roots mapped to neural-mesh elevator pillars."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List

from services.neural_mesh.elevators import PILLAR_NAMES

DEFAULT_ROOTS: List[Dict[str, Any]] = [
    {"id": 1, "key": "root_01_genesis", "pillar": 1, "pillar_key": "ingress"},
    {"id": 2, "key": "root_02_ledger", "pillar": 2, "pillar_key": "tee_verify"},
    {"id": 3, "key": "root_03_consensus", "pillar": 3, "pillar_key": "horizons"},
    {"id": 4, "key": "root_04_telemetry", "pillar": 4, "pillar_key": "precessional_oracle"},
    {"id": 5, "key": "root_05_state", "pillar": 5, "pillar_key": "agent_index"},
    {"id": 6, "key": "root_06_networking", "pillar": 6, "pillar_key": "depin_synth"},
    {"id": 7, "key": "root_07_validation", "pillar": 7, "pillar_key": "tesla_fleet"},
    {"id": 8, "key": "root_08_memepool", "pillar": 8, "pillar_key": "vault_inject"},
    {"id": 9, "key": "root_09_execution", "pillar": 9, "pillar_key": "akash_lease"},
    {"id": 10, "key": "root_10_witness", "pillar": 10, "pillar_key": "solenoid_anchor"},
    {"id": 11, "key": "root_11_crypt", "pillar": 11, "pillar_key": "renaissance"},
    {"id": 12, "key": "root_12_solenoid", "pillar": 12, "pillar_key": "great_delta"},
    {"id": 13, "key": "root_13_mandelor", "pillar": 13, "pillar_key": "sovereign_loop"},
    {"id": 14, "key": "root_14_mainnet", "pillar": 14, "pillar_key": "omni_apex"},
]


@dataclass(frozen=True)
class BookRoot:
    id: int
    key: str
    pillar: int
    pillar_key: str
    state_dir: Path

    @property
    def pillar_name(self) -> str:
        idx = self.pillar - 1
        if 0 <= idx < len(PILLAR_NAMES):
            return PILLAR_NAMES[idx]
        return self.pillar_key


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def load_book_roots(config_path: Path | None = None) -> List[BookRoot]:
    path = config_path or (_repo_root() / "config" / "yieldswarm" / "book_roots.json")
    raw_roots = DEFAULT_ROOTS
    if path.is_file():
        payload = json.loads(path.read_text(encoding="utf-8"))
        raw_roots = payload.get("roots", DEFAULT_ROOTS)

    roots: List[BookRoot] = []
    base = _repo_root() / "data" / "book_roots"
    for item in raw_roots:
        key = item["key"]
        state_dir = Path(item.get("state_dir", base / key))
        if not state_dir.is_absolute():
            state_dir = _repo_root() / state_dir
        roots.append(
            BookRoot(
                id=int(item["id"]),
                key=key,
                pillar=int(item["pillar"]),
                pillar_key=str(item.get("pillar_key", f"pillar_{item['id']}")),
                state_dir=state_dir,
            )
        )
    if len(roots) != 14:
        raise ValueError(f"book roots registry requires exactly 14 entries, got {len(roots)}")
    return roots


def get_root(key: str, config_path: Path | None = None) -> BookRoot:
    for root in load_book_roots(config_path):
        if root.key == key:
            return root
    raise KeyError(f"unknown book root: {key}")
