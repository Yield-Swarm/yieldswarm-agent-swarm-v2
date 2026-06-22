"""Discovery run orchestration."""

from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

from scraper_engine.github_client import GitHubClient
from scraper_engine.manifest import ManifestTarget, ParsedManifest, parse_manifest


@dataclass
class RunConfig:
    targets_file: Path
    output_bucket: str
    depth: int = 3
    include_issues: bool = True
    include_prs: bool = True
    filter_keywords: List[str] = None  # type: ignore[assignment]

    def __post_init__(self) -> None:
        if self.filter_keywords is None:
            self.filter_keywords = []


def _output_root(bucket: str, repo_root: Path) -> Path:
    safe = bucket.replace("/", "_").replace(":", "_")
    return repo_root / ".run" / "scraper" / safe


def run_discovery(cfg: RunConfig, repo_root: Optional[Path] = None) -> Dict[str, Any]:
    repo_root = repo_root or Path(__file__).resolve().parents[1]
    manifest = parse_manifest(cfg.targets_file)
    client = GitHubClient()
    out_dir = _output_root(cfg.output_bucket, repo_root)
    out_dir.mkdir(parents=True, exist_ok=True)

    run_id = time.strftime("%Y%m%dT%H%M%SZ", time.gmtime())
    results: List[Dict[str, Any]] = []

    for target in manifest.targets:
        entry: Dict[str, Any] = {
            "index": target.index,
            "category": target.category,
            "url": target.url,
            "description": target.description,
            "repo": f"{target.owner}/{target.repo}",
        }
        try:
            entry["metadata"] = client.repo_metadata(target.owner, target.repo)
        except RuntimeError as e:
            entry["error"] = str(e)
            results.append(entry)
            continue

        if cfg.depth >= 2:
            if cfg.include_issues:
                try:
                    entry["issues"] = client.list_issues(
                        target.owner, target.repo, cfg.filter_keywords
                    )
                except RuntimeError as e:
                    entry["issues_error"] = str(e)
            if cfg.include_prs:
                try:
                    entry["pull_requests"] = client.list_pulls(
                        target.owner, target.repo, cfg.filter_keywords
                    )
                except RuntimeError as e:
                    entry["pull_requests_error"] = str(e)

        if cfg.depth >= 3 and cfg.filter_keywords:
            try:
                entry["code_hits"] = client.search_code_snippets(
                    target.owner, target.repo, cfg.filter_keywords
                )
            except RuntimeError as e:
                entry["code_hits_error"] = str(e)

        results.append(entry)

    payload = {
        "run_id": run_id,
        "preset": asdict(manifest.preset),
        "config": {
            "targets_file": str(cfg.targets_file),
            "output_bucket": cfg.output_bucket,
            "depth": cfg.depth,
            "include_issues": cfg.include_issues,
            "include_prs": cfg.include_prs,
            "filter_keywords": cfg.filter_keywords,
        },
        "target_count": len(manifest.targets),
        "results": results,
    }

    out_file = out_dir / f"discovery-{run_id}.json"
    out_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    summary_file = out_dir / "latest.json"
    summary_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    manifest_copy = out_dir / "manifest.snapshot.txt"
    manifest_copy.write_text(cfg.targets_file.read_text(encoding="utf-8"), encoding="utf-8")

    return {
        "ok": True,
        "run_id": run_id,
        "output_dir": str(out_dir),
        "output_file": str(out_file),
        "targets_scanned": len(results),
        "matches_with_issues": sum(1 for r in results if r.get("issues")),
        "matches_with_prs": sum(1 for r in results if r.get("pull_requests")),
    }
