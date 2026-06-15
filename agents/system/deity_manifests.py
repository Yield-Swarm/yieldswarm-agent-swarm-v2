"""Single-Origin Deity manifest generation and loading."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List

from agents.system.constants import DEITY_MANIFEST_COUNT, METAL_SKINS

ORIGIN = "single-origin-prime"

DOMAINS = (
    "alpha-oracle",
    "beta-signal",
    "gamma-fractal",
    "delta-hedge",
    "epsilon-momentum",
    "zeta-volatility",
    "eta-yield",
    "theta-liquidity",
    "iota-governance",
    "kappa-sentiment",
    "lambda-tensor",
    "mu-correlation",
    "nu-arbitrage",
)

VECTORS = (
    "north",
    "north-northeast",
    "northeast",
    "east-northeast",
    "east",
    "east-southeast",
    "southeast",
    "south-southeast",
    "south",
    "south-southwest",
    "southwest",
    "west-southwest",
    "west",
)


def deity_manifest_name(index: int) -> str:
    return f"sod-{index:03d}"


def _build_manifest(index: int) -> Dict[str, object]:
    domain = DOMAINS[(index - 1) % len(DOMAINS)]
    vector = VECTORS[((index - 1) // len(DOMAINS)) % len(VECTORS)]
    skin = METAL_SKINS[(index - 1) % len(METAL_SKINS)]

    return {
        "manifest_id": deity_manifest_name(index),
        "class": "single-origin-deity",
        "origin": ORIGIN,
        "domain": domain,
        "vector": vector,
        "metal_skin": skin,
        "mutation_affinity": round(0.65 + (index % 7) * 0.04, 4),
        "heartbeat_interval_seconds": 420,
        "proof_profile": "arena-zk-schnorr-v1",
    }


def _manifest_dir(root_dir: Path) -> Path:
    return root_dir / "system" / "manifests" / "deities"


def ensure_deity_manifests(root_dir: Path | str) -> List[Path]:
    """Guarantee that exactly 169 deity manifests exist on disk."""
    root_path = Path(root_dir)
    manifest_dir = _manifest_dir(root_path)
    manifest_dir.mkdir(parents=True, exist_ok=True)

    created_or_updated: List[Path] = []
    manifests_index = []
    for index in range(1, DEITY_MANIFEST_COUNT + 1):
        payload = _build_manifest(index)
        file_path = manifest_dir / f"{payload['manifest_id']}.json"
        rendered = json.dumps(payload, indent=2, sort_keys=True) + "\n"
        if not file_path.exists() or file_path.read_text(encoding="utf-8") != rendered:
            file_path.write_text(rendered, encoding="utf-8")
            created_or_updated.append(file_path)
        manifests_index.append(payload["manifest_id"])

    index_path = root_path / "system" / "manifests" / "index.json"
    index_payload = {
        "origin": ORIGIN,
        "count": DEITY_MANIFEST_COUNT,
        "manifests": manifests_index,
    }
    index_rendered = json.dumps(index_payload, indent=2, sort_keys=True) + "\n"
    if not index_path.exists() or index_path.read_text(encoding="utf-8") != index_rendered:
        index_path.parent.mkdir(parents=True, exist_ok=True)
        index_path.write_text(index_rendered, encoding="utf-8")
        created_or_updated.append(index_path)

    return created_or_updated


def load_deity_manifests(root_dir: Path | str) -> Dict[str, Dict[str, object]]:
    """Load all deity manifests as an id->manifest mapping."""
    root_path = Path(root_dir)
    manifest_dir = _manifest_dir(root_path)
    manifests: Dict[str, Dict[str, object]] = {}
    for path in sorted(manifest_dir.glob("*.json")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        manifests[payload["manifest_id"]] = payload
    if len(manifests) != DEITY_MANIFEST_COUNT:
        raise ValueError(
            f"Expected {DEITY_MANIFEST_COUNT} deity manifests, found {len(manifests)}"
        )
    return manifests
