"""CLI entry for scraper_engine."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from scraper_engine.runner import RunConfig, run_discovery

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / "manifests" / "scraper-discovery-manifest.txt"


def _parse_bool(value: str) -> bool:
    return value.lower() in ("1", "true", "yes", "on")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="YieldSwarm DePIN / multi-mining GitHub discovery scraper (public metadata only)",
    )
    sub = p.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Execute discovery pass over manifest targets")
    run.add_argument(
        "--targets-file",
        default=str(DEFAULT_MANIFEST),
        help="Path to discovery manifest (default: manifests/scraper-discovery-manifest.txt)",
    )
    run.add_argument(
        "--output-bucket",
        default="yieldswarm-telemetry-singapore",
        help="Logical output bucket name (stored under .run/scraper/<bucket>/)",
    )
    run.add_argument("--depth", type=int, default=3, help="1=metadata, 2=+issues/PRs, 3=+code search")
    run.add_argument("--include-issues", default="true", help="Include GitHub issues (true/false)")
    run.add_argument("--include-prs", default="true", help="Include GitHub pull requests (true/false)")
    run.add_argument(
        "--filter-keywords",
        default="rate-limit,token-leak,access-bypass,telemetry-skew,oidc-validation",
        help="Comma-separated keywords for issue/PR/code filtering",
    )
    run.add_argument("--json", action="store_true", help="Print JSON summary to stdout")

    for name in ("list-targets", "list"):
        lp = sub.add_parser(name, help="Print parsed manifest targets")
        lp.add_argument("--targets-file", default=str(DEFAULT_MANIFEST))
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    if args.command in ("list-targets", "list"):
        from scraper_engine.manifest import parse_manifest

        manifest = parse_manifest(Path(getattr(args, "targets_file", DEFAULT_MANIFEST)))
        for t in manifest.targets:
            print(f"{t.index:2d}  {t.owner}/{t.repo}  [{t.category}]")
        return 0

    if args.command == "run":
        keywords = [k.strip() for k in args.filter_keywords.split(",") if k.strip()]
        cfg = RunConfig(
            targets_file=Path(args.targets_file),
            output_bucket=args.output_bucket,
            depth=max(1, min(3, args.depth)),
            include_issues=_parse_bool(args.include_issues),
            include_prs=_parse_bool(args.include_prs),
            filter_keywords=keywords,
        )
        summary = run_discovery(cfg, REPO_ROOT)
        print(json.dumps(summary, indent=2))
        return 0 if summary.get("ok") else 1

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
