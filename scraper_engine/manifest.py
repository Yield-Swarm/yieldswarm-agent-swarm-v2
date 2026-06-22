"""Parse scraper discovery manifest files."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

_GH_RE = re.compile(r"https?://github\.com/(?P<owner>[^/]+)/(?P<repo>[^/\s]+)")
_META_RE = re.compile(
    r"TARGET_ACCOUNT_CONTEXT:\s*(?P<account>[^\n]+)|"
    r"NETWORK_ROUTING_TIER:\s*(?P<network>[^\n]+)|"
    r"BACKEND_DB_ENGINE:\s*(?P<db>[^\n]+)"
)


@dataclass
class ManifestTarget:
    index: int
    url: str
    owner: str
    repo: str
    category: str
    description: str


@dataclass
class ManifestPreset:
    account_context: str = ""
    network_routing_tier: str = ""
    backend_db_engine: str = ""


@dataclass
class ParsedManifest:
    preset: ManifestPreset
    targets: List[ManifestTarget]


def _category_from_line(line: str) -> Optional[str]:
    if line.startswith("CATEGORY "):
        return line.split(":", 1)[0].strip()
    return None


def parse_manifest(path: Path) -> ParsedManifest:
    text = path.read_text(encoding="utf-8")
    preset = ManifestPreset()
    for m in _META_RE.finditer(text):
        if m.group("account"):
            preset.account_context = m.group("account").strip()
        if m.group("network"):
            preset.network_routing_tier = m.group("network").strip()
        if m.group("db"):
            preset.backend_db_engine = m.group("db").strip()

    targets: List[ManifestTarget] = []
    category = "UNCATEGORIZED"
    pending_index: Optional[int] = None
    pending_url: Optional[str] = None

    for raw in text.splitlines():
        line = raw.strip()
        cat = _category_from_line(line)
        if cat:
            category = cat
            continue

        num_match = re.match(r"^(\d+)\.\s+(https://github\.com/\S+)", line)
        if num_match:
            pending_index = int(num_match.group(1))
            pending_url = num_match.group(2).rstrip("/")
            continue

        if line.startswith("- Description:") and pending_url and pending_index is not None:
            m = _GH_RE.match(pending_url)
            if not m:
                pending_index = pending_url = None
                continue
            targets.append(
                ManifestTarget(
                    index=pending_index,
                    url=pending_url,
                    owner=m.group("owner"),
                    repo=m.group("repo").removesuffix(".git"),
                    category=category,
                    description=line.split(":", 1)[1].strip(),
                )
            )
            pending_index = pending_url = None

    return ParsedManifest(preset=preset, targets=targets)
