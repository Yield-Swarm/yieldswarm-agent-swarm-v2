#!/usr/bin/env python3
"""Render the Akash SDL template with environment variables.

Supports ${VAR} and ${VAR:-default} placeholders so the committed SDL can stay
safe for review while deployment output contains concrete image tags and keys.
"""

from __future__ import annotations

import argparse
import os
import re
from pathlib import Path


PLACEHOLDER_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::-(.*?))?\}")
REQUIRED = {
    "YIELDSWARM_ROUTER_API_KEY",
    "OPENROUTER_API_KEY",
    "FIREWORKS_API_KEY",
    "AKASH_OLLAMA_BASE_URL",
}


def resolve(match: re.Match[str], allow_empty: bool) -> str:
    name = match.group(1)
    default = match.group(2)
    value = os.environ.get(name)
    if value is None or value == "":
        if default is not None:
            return default
        if name in REQUIRED and not allow_empty:
            raise SystemExit(f"Missing required environment variable: {name}")
        return ""
    return value


def main() -> None:
    parser = argparse.ArgumentParser(description="Render the YieldSwarm Akash SDL")
    parser.add_argument(
        "--template",
        default="deploy/akash-odysseus.sdl.yml",
        help="SDL template path",
    )
    parser.add_argument(
        "--output",
        default="deploy/rendered/akash-odysseus.sdl.yml",
        help="Rendered SDL output path",
    )
    parser.add_argument(
        "--allow-empty",
        action="store_true",
        help="Render missing required values as empty strings for dry-run linting",
    )
    args = parser.parse_args()

    template = Path(args.template)
    output = Path(args.output)
    rendered = PLACEHOLDER_RE.sub(
        lambda match: resolve(match, args.allow_empty),
        template.read_text(encoding="utf-8"),
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(rendered, encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()
