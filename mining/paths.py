"""Path helpers — fix accidental literal ``~`` directories from escaped shell ``\\~``."""

from __future__ import annotations

import os
from pathlib import Path


def collapse_literal_tilde(path: Path) -> Path:
    """
    Repair paths like ``.../yieldswarm-agent-swarm-v2/~/yieldswarm-agent-swarm-v2/.run``.

    When operators run ``cd \\~/repo`` the shell creates a directory literally named ``~``.
    """
    raw = str(path)
    home = str(Path.home())

    # Absolute home + literal ~ segment
    needle = f"{home}/~/"
    while needle in raw:
        raw = raw.replace(needle, f"{home}/", 1)

    # Any remaining /~/ in the path
    while "/~/" in raw:
        raw = raw.replace("/~/", "/", 1)

    if raw.endswith("/~"):
        raw = raw[:-2]

    parts = Path(os.path.expanduser(raw)).parts
    deduped: list[str] = []
    for part in parts:
        if deduped and deduped[-1] == part:
            continue
        deduped.append(part)
    return Path(*deduped) if deduped else Path(raw)


def resolve_run_dir(run_dir: str, repo_root: Path) -> Path:
    """Resolve mining run directory relative to repo; never nest on literal ``~``."""
    p = Path(os.path.expanduser(run_dir))
    if not p.is_absolute():
        p = repo_root / p
    return collapse_literal_tilde(p.resolve())
