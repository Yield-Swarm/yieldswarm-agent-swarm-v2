"""CLI table and HTML dashboard for Alchemy RPC smoke tests."""

from __future__ import annotations

import html
import json
from pathlib import Path
from typing import List

from services.alchemy.health_checker import ChainCheckResult, SmokeTestReport


def _status_icon(status: str) -> str:
    return "✅" if status == "pass" else "❌"


def render_cli_table(results: List[ChainCheckResult], *, title: str) -> str:
    lines = [title, "-" * len(title)]
    header = f"{'Chain Name':<42} {'St':^4} {'Latency':>9}  {'Last Block':<12} Notes"
    lines.append(header)
    lines.append("-" * len(header))
    for row in results:
        name = row.network.name[:42]
        block = (row.last_block or "-")[:12]
        notes = (row.notes or "-")[:60]
        lines.append(
            f"{name:<42} {_status_icon(row.status):^4} {row.latency_ms:>7.0f}ms  {block:<12} {notes}"
        )
    return "\n".join(lines)


def render_cli_summary(report: SmokeTestReport) -> str:
    parts = [
        "",
        "=" * 72,
        "ALCHEMY MULTI-CHAIN RPC SMOKE TEST",
        "=" * 72,
        f"API key (masked): {report.api_key_mask}",
        f"Window: {report.started_at} → {report.finished_at}",
        f"Total: {report.total}  Passed: {report.passed}  Failed: {report.failed}",
    ]
    if report.prefix_warning:
        parts.append(f"Warning: {report.prefix_warning}")
    parts.append("")
    parts.append(render_cli_table(report.mainnet_results, title="MAINNETS"))
    parts.append("")
    parts.append(render_cli_table(report.testnet_results, title="TESTNETS"))
    if report.failed_chains:
        parts.append("")
        parts.append("FAILED CHAINS (action required):")
        for row in report.failed_chains:
            parts.append(f"  ❌ {row.network.name}: {row.notes or row.error}")
    parts.append("=" * 72)
    return "\n".join(parts)


def _rows_html(results: List[ChainCheckResult]) -> str:
    rows = []
    for row in results:
        cls = "pass" if row.status == "pass" else "fail"
        rows.append(
            "<tr class='{cls}'>"
            "<td>{name}</td>"
            "<td>{platform}</td>"
            "<td>{family}</td>"
            "<td>{status}</td>"
            "<td>{latency:.0f}</td>"
            "<td>{chain}</td>"
            "<td>{block}</td>"
            "<td>{notes}</td>"
            "</tr>".format(
                cls=cls,
                name=html.escape(row.network.name),
                platform=html.escape(row.network.platform),
                family=html.escape(row.network.rpc_family),
                status=_status_icon(row.status),
                latency=row.latency_ms,
                chain=html.escape(row.chain_id or "-"),
                block=html.escape(row.last_block or "-"),
                notes=html.escape(row.notes or "-"),
            )
        )
    return "\n".join(rows)


def render_html_report(report: SmokeTestReport) -> str:
    failed_json = html.escape(
        json.dumps([r.network.name for r in report.failed_chains], indent=2)
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Alchemy RPC Smoke Test — {html.escape(report.finished_at)}</title>
  <style>
    :root {{ font-family: ui-sans-serif, system-ui, sans-serif; background: #0b0f14; color: #e8eef5; }}
    body {{ margin: 0; padding: 1.5rem; }}
    h1 {{ font-size: 1.35rem; margin: 0 0 0.5rem; }}
    .meta {{ color: #9ab; margin-bottom: 1.25rem; font-size: 0.9rem; }}
    .cards {{ display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }}
    .card {{ background: #121a24; border: 1px solid #243044; border-radius: 8px; padding: 1rem 1.25rem; min-width: 120px; }}
    .card strong {{ display: block; font-size: 1.6rem; }}
    h2 {{ margin-top: 2rem; font-size: 1.1rem; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 0.82rem; margin-top: 0.5rem; }}
    th, td {{ border-bottom: 1px solid #243044; padding: 0.45rem 0.55rem; text-align: left; vertical-align: top; }}
    th {{ color: #9ab; position: sticky; top: 0; background: #0b0f14; }}
    tr.pass td:nth-child(4) {{ color: #3dd68c; }}
    tr.fail td:nth-child(4) {{ color: #f87171; font-weight: 600; }}
    .warn {{ color: #fbbf24; }}
    pre {{ background: #121a24; padding: 1rem; border-radius: 8px; overflow-x: auto; }}
  </style>
</head>
<body>
  <h1>Alchemy Multi-Chain RPC Health</h1>
  <div class="meta">
    Key: <code>{html.escape(report.api_key_mask)}</code> ·
    {html.escape(report.started_at)} → {html.escape(report.finished_at)}
    {" · <span class='warn'>" + html.escape(report.prefix_warning) + "</span>" if report.prefix_warning else ""}
  </div>
  <div class="cards">
    <div class="card"><span>Total</span><strong>{report.total}</strong></div>
    <div class="card"><span>Passed</span><strong style="color:#3dd68c">{report.passed}</strong></div>
    <div class="card"><span>Failed</span><strong style="color:#f87171">{report.failed}</strong></div>
  </div>
  <h2>Mainnets ({len(report.mainnet_results)})</h2>
  <table>
    <thead><tr><th>Chain</th><th>Platform</th><th>Family</th><th>Status</th><th>Latency ms</th><th>Chain ID</th><th>Last Block</th><th>Notes</th></tr></thead>
    <tbody>{_rows_html(report.mainnet_results)}</tbody>
  </table>
  <h2>Testnets ({len(report.testnet_results)})</h2>
  <table>
    <thead><tr><th>Chain</th><th>Platform</th><th>Family</th><th>Status</th><th>Latency ms</th><th>Chain ID</th><th>Last Block</th><th>Notes</th></tr></thead>
    <tbody>{_rows_html(report.testnet_results)}</tbody>
  </table>
  <h2>Failed chains</h2>
  <pre>{failed_json}</pre>
</body>
</html>
"""


def write_html_report(report: SmokeTestReport, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(render_html_report(report), encoding="utf-8")


def write_json_report(report: SmokeTestReport, path: Path) -> None:
    payload = {
        "startedAt": report.started_at,
        "finishedAt": report.finished_at,
        "apiKeyMask": report.api_key_mask,
        "prefixWarning": report.prefix_warning,
        "total": report.total,
        "passed": report.passed,
        "failed": report.failed,
        "mainnets": [
            {
                "name": r.network.name,
                "slug": r.network.slug,
                "platform": r.network.platform,
                "rpcFamily": r.network.rpc_family,
                "status": r.status,
                "latencyMs": r.latency_ms,
                "chainId": r.chain_id,
                "lastBlock": r.last_block,
                "notes": r.notes,
                "checks": r.checks,
            }
            for r in report.mainnet_results
        ],
        "testnets": [
            {
                "name": r.network.name,
                "slug": r.network.slug,
                "platform": r.network.platform,
                "rpcFamily": r.network.rpc_family,
                "status": r.status,
                "latencyMs": r.latency_ms,
                "chainId": r.chain_id,
                "lastBlock": r.last_block,
                "notes": r.notes,
                "checks": r.checks,
            }
            for r in report.testnet_results
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
