"""Shared import bootstrap for agent scripts executed as standalone files."""

from __future__ import annotations

import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
AGENTS_DIR = REPO_ROOT / "agents"

for entry in (str(REPO_ROOT), str(AGENTS_DIR)):
    if entry not in sys.path:
        sys.path.insert(0, entry)
