#!/usr/bin/env python3
"""
Bifröst bridge — pin staged static sites to IPFS and emit chain gateway manifest.

Used by scripts/deploy-ipfs-blockchain.sh
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import error, request


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def ipfs_available() -> bool:
    try:
        subprocess.run(["ipfs", "--version"], capture_output=True, check=True, timeout=10)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return False


def docker_available() -> bool:
    try:
        subprocess.run(["docker", "--version"], capture_output=True, check=True, timeout=10)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return False


def ipfs_add_recursive(staging: Path, dry_run: bool = False) -> str:
    if dry_run:
        return "bafybei-dry-run-placeholder-cid"

    if ipfs_available():
        out = subprocess.check_output(
            ["ipfs", "add", "-r", "-Q", "--cid-version", "1", str(staging)],
            text=True,
            timeout=600,
        )
        return out.strip().splitlines()[-1]

    if docker_available():
        staging = staging.resolve()
        out = subprocess.check_output(
            [
                "docker",
                "run",
                "--rm",
                "-v",
                f"{staging}:/export:ro",
                "ipfs/kubo:v0.32.1",
                "ipfs",
                "add",
                "-r",
                "-Q",
                "--cid-version",
                "1",
                "/export",
            ],
            text=True,
            timeout=600,
        )
        return out.strip().splitlines()[-1]

    raise RuntimeError("ipfs CLI or Docker required to compute directory CID (install kubo or docker)")


def pinata_headers(jwt: str | None, api_key: str | None, secret: str | None) -> dict[str, str]:
    if jwt:
        return {"Authorization": f"Bearer {jwt}"}
    if api_key and secret:
        return {"pinata_api_key": api_key, "pinata_secret_api_key": secret}
    raise RuntimeError("Pinata credentials missing — set PINATA_JWT or PINATA_API_KEY + PINATA_SECRET")


def pinata_pin_by_hash(
    cid: str,
    *,
    jwt: str | None,
    api_key: str | None,
    secret: str | None,
    name: str,
    dry_run: bool = False,
) -> dict[str, Any]:
    if dry_run:
        return {"pinned": True, "dryRun": True, "IpfsHash": cid}

    body = json.dumps(
        {
            "hashToPin": cid,
            "pinataMetadata": {"name": name},
        }
    ).encode()
    req = request.Request(
        "https://api.pinata.cloud/pinning/pinByHash",
        data=body,
        headers={**pinata_headers(jwt, api_key, secret), "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode())
    except error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise RuntimeError(f"Pinata pinByHash failed ({exc.code}): {detail}") from exc


def pinata_upload_tar(
    staging: Path,
    *,
    jwt: str | None,
    api_key: str | None,
    secret: str | None,
    name: str,
    dry_run: bool = False,
) -> str:
    """Fallback: upload tarball when local ipfs add is unavailable."""
    if dry_run:
        return "bafybei-dry-run-tar-upload"

    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        tar_path = Path(tmp.name)
    try:
        with tarfile.open(tar_path, "w:gz") as tar:
            tar.add(staging, arcname=".")
        boundary = "----BifrostBoundary7MA4YWxkTrZu0gW"
        body_parts: list[bytes] = []

        def add_field(field_name: str, value: str) -> None:
            body_parts.append(f"--{boundary}\r\n".encode())
            body_parts.append(f'Content-Disposition: form-data; name="{field_name}"\r\n\r\n'.encode())
            body_parts.append(value.encode())
            body_parts.append(b"\r\n")

        meta = json.dumps({"name": name})
        opts = json.dumps({"cidVersion": 1, "wrapWithDirectory": True})
        add_field("pinataMetadata", meta)
        add_field("pinataOptions", opts)

        body_parts.append(f"--{boundary}\r\n".encode())
        body_parts.append(
            f'Content-Disposition: form-data; name="file"; filename="{name}.tar.gz"\r\n'.encode()
        )
        body_parts.append(b"Content-Type: application/gzip\r\n\r\n")
        body_parts.append(tar_path.read_bytes())
        body_parts.append(b"\r\n")
        body_parts.append(f"--{boundary}--\r\n".encode())
        payload = b"".join(body_parts)

        req = request.Request(
            "https://api.pinata.cloud/pinning/pinFileToIPFS",
            data=payload,
            headers={
                **pinata_headers(jwt, api_key, secret),
                "Content-Type": f"multipart/form-data; boundary={boundary}",
            },
            method="POST",
        )
        with request.urlopen(req, timeout=300) as resp:
            result = json.loads(resp.read().decode())
            return str(result.get("IpfsHash") or result.get("cid") or "")
    finally:
        tar_path.unlink(missing_ok=True)


def verify_gateway(gateway: str, cid: str, dry_run: bool = False) -> bool:
    if dry_run:
        return True
    url = f"{gateway.rstrip('/')}/{cid}/"
    req = request.Request(url, method="GET")
    try:
        with request.urlopen(req, timeout=20) as resp:
            return 200 <= resp.status < 400
    except error.URLError:
        return False


def build_manifest(
    *,
    root_cid: str,
    gateway: str,
    local_api: str,
    build_tag: str,
    realms: dict[str, Any],
) -> dict[str, Any]:
    return {
        "bridge": "bifrost-v1",
        "name": "YieldSwarm Rainbow Bridge",
        "generatedAt": _now_iso(),
        "buildTag": build_tag,
        "rootCid": root_cid,
        "ipfsGateway": gateway.rstrip("/"),
        "localApi": local_api.rstrip("/"),
        "realms": realms,
        "urls": {
            "ipfs": f"{gateway.rstrip('/')}/{root_cid}/",
            "commandCenter": f"{gateway.rstrip('/')}/{root_cid}/dashboard/command-center.html",
            "sovereignDashboard": f"{gateway.rstrip('/')}/{root_cid}/dashboard/sovereign-dashboard.html",
            "arena": f"{gateway.rstrip('/')}/{root_cid}/frontend/dist/index.html",
        },
    }


def default_realms(root_cid: str, gateway: str) -> dict[str, Any]:
    base = f"{gateway.rstrip('/')}/{root_cid}"
    return {
        "yieldswarm.xyz": {
            "label": "Official Realm",
            "cid": root_cid,
            "gateway": base,
            "resolved": True,
        },
        "helixchain.blockchain": {
            "label": "Helix Chain",
            "cid": root_cid,
            "gateway": f"{base}/dashboard/command-center.html",
            "solenoid": 2,
            "resolved": False,
        },
        "nexuschain.blockchain": {
            "label": "Nexus Chain",
            "cid": root_cid,
            "gateway": f"{base}/dashboard/sovereign-dashboard.html",
            "solenoid": 1,
            "resolved": False,
        },
        "shadowchain.blockchain": {
            "label": "Shadow Chain",
            "cid": root_cid,
            "gateway": f"{base}/public/index.html",
            "solenoid": 3,
            "resolved": False,
        },
    }


def write_dashboard_config(repo_root: Path, manifest: dict[str, Any]) -> None:
    out = repo_root / "dashboard" / "config.js"
    cfg = {
        "buildTag": manifest.get("buildTag"),
        "generatedAt": manifest.get("generatedAt"),
        "bifrost": {
            "rootCid": manifest.get("rootCid"),
            "gateway": manifest.get("ipfsGateway"),
            "urls": manifest.get("urls", {}),
            "realms": manifest.get("realms", {}),
        },
        "workerUrls": [],
        "primaryWorker": manifest.get("localApi"),
    }
    out.write_text(
        "// AUTO-GENERATED by scripts/deploy-ipfs-blockchain.sh — do not edit.\n"
        f"// Generated: {cfg['generatedAt']}  |  build: {cfg['buildTag']}\n"
        f"window.YIELDSWARM_CONFIG = {json.dumps(cfg, indent=2)};\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Pin Bifröst staging bundle to IPFS")
    parser.add_argument("--staging", required=True, help="Staged static site directory")
    parser.add_argument("--manifest-out", required=True, help="Output bifrost-manifest.json path")
    parser.add_argument("--repo-root", default=".", help="Repository root")
    parser.add_argument("--build-tag", default=os.environ.get("IMAGE_TAG", "local"))
    parser.add_argument("--gateway", default=os.environ.get("IPFS_GATEWAY", "https://gateway.pinata.cloud/ipfs"))
    parser.add_argument("--local-api", default=os.environ.get("API_BASE", "http://127.0.0.1:8080"))
    parser.add_argument("--pin-name", default="yieldswarm-bifrost")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-pinata", action="store_true")
    parser.add_argument("--cid", default=os.environ.get("BIFROST_ROOT_CID", ""))
    args = parser.parse_args()

    staging = Path(args.staging).resolve()
    if not staging.is_dir():
        print(f"staging directory missing: {staging}", file=sys.stderr)
        return 1

    jwt = os.environ.get("PINATA_JWT") or None
    api_key = os.environ.get("PINATA_API_KEY") or None
    secret = os.environ.get("PINATA_SECRET") or None
    pinata_ready = bool(jwt or (api_key and secret))

    root_cid = args.cid.strip()
    if not root_cid:
        try:
            root_cid = ipfs_add_recursive(staging, dry_run=args.dry_run)
        except RuntimeError:
            if pinata_ready and not args.skip_pinata:
                root_cid = pinata_upload_tar(
                    staging,
                    jwt=jwt,
                    api_key=api_key,
                    secret=secret,
                    name=args.pin_name,
                    dry_run=args.dry_run,
                )
            else:
                raise

    if pinata_ready and not args.skip_pinata and not args.dry_run:
        pinata_pin_by_hash(
            root_cid,
            jwt=jwt,
            api_key=api_key,
            secret=secret,
            name=args.pin_name,
            dry_run=args.dry_run,
        )

    realms = default_realms(root_cid, args.gateway)
    manifest = build_manifest(
        root_cid=root_cid,
        gateway=args.gateway,
        local_api=args.local_api,
        build_tag=args.build_tag,
        realms=realms,
    )
    manifest["gatewayLive"] = verify_gateway(args.gateway, root_cid, dry_run=args.dry_run)

    manifest_out = Path(args.manifest_out)
    manifest_out.parent.mkdir(parents=True, exist_ok=True)
    manifest_out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    repo_root = Path(args.repo_root).resolve()
    write_dashboard_config(repo_root, manifest)

    print(json.dumps({"ok": True, "rootCid": root_cid, "gatewayLive": manifest["gatewayLive"]}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
