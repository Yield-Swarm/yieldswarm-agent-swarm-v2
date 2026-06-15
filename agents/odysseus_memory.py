"""Odysseus long-term memory for the YieldSwarm agent mesh.

The module centralizes agent memory around ChromaDB while keeping a JSONL
fallback/outbox so cloud workers can keep operating during bootstrap or outages.
Every agent should write through this adapter instead of inventing per-agent
state files.
"""

from __future__ import annotations

import json
import os
import socket
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from hashlib import sha256
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence
from urllib import request
from urllib.error import URLError

try:  # ChromaDB is optional at import time for local tests and bootstrap.
    import chromadb  # type: ignore
except Exception:  # pragma: no cover - exercised when dependency is absent.
    chromadb = None  # type: ignore


MEMORY_COLLECTIONS = {
    "agent_mutations": "Mutation events, versions, and outcomes for mutated agents.",
    "performance_history": "Metrics and historical performance observations.",
    "deity_identities": "Identity, role, and authority records for Deity agents.",
    "cross_agent_learnings": "Reusable lessons and findings shared across agents.",
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _json_default(value: Any) -> str:
    if isinstance(value, Path):
        return str(value)
    return str(value)


def _safe_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, default=_json_default)


def _metadata_value(value: Any) -> Optional[str | int | float | bool]:
    if value is None:
        return None
    if isinstance(value, (str, int, float, bool)):
        return value
    return _safe_json(value)


def _clean_metadata(metadata: Dict[str, Any]) -> Dict[str, str | int | float | bool]:
    cleaned: Dict[str, str | int | float | bool] = {}
    for key, value in metadata.items():
        safe_value = _metadata_value(value)
        if safe_value is not None:
            cleaned[key] = safe_value
    return cleaned


def _stable_hash(parts: Iterable[Any]) -> str:
    digest = sha256()
    for part in parts:
        digest.update(_safe_json(part).encode("utf-8"))
        digest.update(b"\0")
    return digest.hexdigest()


def build_agent_id(shard_id: int, shard_index: int) -> str:
    """Build the canonical ID for one of the 10,080 sharded agents."""

    return f"ys-shard-{shard_id:03d}-agent-{shard_index:03d}"


@dataclass(frozen=True)
class OdysseusMemoryConfig:
    chroma_mode: str = "persistent"
    chroma_host: Optional[str] = None
    chroma_port: int = 8000
    chroma_ssl: bool = False
    chroma_token: Optional[str] = None
    chroma_tenant: Optional[str] = None
    chroma_database: Optional[str] = None
    persist_dir: str = ".odysseus/chroma"
    collection_prefix: str = "yieldswarm_odysseus"
    node_id: str = field(
        default_factory=lambda: os.getenv("ODYSSEUS_NODE_ID")
        or f"{socket.gethostname()}-{os.getpid()}"
    )
    agent_count_total: int = 10080
    agents_per_shard: int = 84
    shard_count: int = 120
    sync_peers: Sequence[str] = field(default_factory=list)
    sync_token: Optional[str] = None
    sync_outbox_path: str = ".odysseus/memory-outbox.jsonl"
    sync_cursor_dir: str = ".odysseus/sync-cursors"

    @classmethod
    def from_env(cls) -> "OdysseusMemoryConfig":
        sync_peers_raw = os.getenv("ODYSSEUS_SYNC_PEERS", "")
        sync_peers: Sequence[str]
        if sync_peers_raw.strip().startswith("["):
            sync_peers = json.loads(sync_peers_raw)
        else:
            sync_peers = [
                peer.strip()
                for peer in sync_peers_raw.split(",")
                if peer.strip()
            ]

        return cls(
            chroma_mode=os.getenv("ODYSSEUS_CHROMA_MODE", "persistent").lower(),
            chroma_host=os.getenv("ODYSSEUS_CHROMA_HOST") or None,
            chroma_port=int(os.getenv("ODYSSEUS_CHROMA_PORT", "8000")),
            chroma_ssl=os.getenv("ODYSSEUS_CHROMA_SSL", "false").lower() == "true",
            chroma_token=os.getenv("ODYSSEUS_CHROMA_TOKEN") or None,
            chroma_tenant=os.getenv("ODYSSEUS_CHROMA_TENANT") or None,
            chroma_database=os.getenv("ODYSSEUS_CHROMA_DATABASE") or None,
            persist_dir=os.getenv("ODYSSEUS_CHROMA_PERSIST_DIR", ".odysseus/chroma"),
            collection_prefix=os.getenv(
                "ODYSSEUS_CHROMA_COLLECTION_PREFIX",
                "yieldswarm_odysseus",
            ),
            node_id=os.getenv("ODYSSEUS_NODE_ID")
            or f"{socket.gethostname()}-{os.getpid()}",
            agent_count_total=int(os.getenv("AGENT_COUNT_TOTAL", "10080")),
            agents_per_shard=int(os.getenv("AGENTS_PER_SHARD", "84")),
            shard_count=int(os.getenv("CRON_SHARD_COUNT", "120")),
            sync_peers=sync_peers,
            sync_token=os.getenv("ODYSSEUS_SYNC_TOKEN") or None,
            sync_outbox_path=os.getenv(
                "ODYSSEUS_SYNC_OUTBOX_PATH",
                ".odysseus/memory-outbox.jsonl",
            ),
            sync_cursor_dir=os.getenv(
                "ODYSSEUS_SYNC_CURSOR_DIR",
                ".odysseus/sync-cursors",
            ),
        )


class _JsonlCollection:
    """Small durable fallback with a Chroma-like surface for tests/bootstrap."""

    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def upsert(
        self,
        *,
        ids: Sequence[str],
        documents: Sequence[str],
        metadatas: Sequence[Dict[str, Any]],
    ) -> None:
        existing = {record["id"]: record for record in self._read_records()}
        for item_id, document, metadata in zip(ids, documents, metadatas):
            existing[item_id] = {
                "id": item_id,
                "document": document,
                "metadata": metadata,
            }
        with self.path.open("w", encoding="utf-8") as handle:
            for record in existing.values():
                handle.write(_safe_json(record) + "\n")

    def get(self, ids: Sequence[str]) -> Dict[str, List[Any]]:
        wanted = set(ids)
        records = [record for record in self._read_records() if record["id"] in wanted]
        return {
            "ids": [record["id"] for record in records],
            "documents": [record["document"] for record in records],
            "metadatas": [record["metadata"] for record in records],
        }

    def query(self, *, query_texts: Sequence[str], n_results: int) -> Dict[str, List[Any]]:
        query_text = " ".join(query_texts).lower()
        scored = []
        for record in self._read_records():
            document = record["document"]
            score = document.lower().count(query_text) if query_text else 0
            if query_text and query_text in document.lower():
                score += 10
            scored.append((score, record))
        scored.sort(key=lambda item: item[0], reverse=True)
        selected = [record for _, record in scored[:n_results]]
        return {
            "ids": [[record["id"] for record in selected]],
            "documents": [[record["document"] for record in selected]],
            "metadatas": [[record["metadata"] for record in selected]],
            "distances": [[1.0 / (score + 1) for score, _ in scored[:n_results]]],
        }

    def _read_records(self) -> List[Dict[str, Any]]:
        if not self.path.exists():
            return []
        records: List[Dict[str, Any]] = []
        with self.path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if line:
                    records.append(json.loads(line))
        return records


class OdysseusMemory:
    """Central read/write interface for all long-term agent memory."""

    def __init__(self, config: Optional[OdysseusMemoryConfig] = None):
        self.config = config or OdysseusMemoryConfig.from_env()
        self.outbox_path = Path(self.config.sync_outbox_path)
        self.outbox_path.parent.mkdir(parents=True, exist_ok=True)
        self.cursor_dir = Path(self.config.sync_cursor_dir)
        self.cursor_dir.mkdir(parents=True, exist_ok=True)
        self.client = self._build_chroma_client()
        self.collections = {
            name: self._get_collection(name)
            for name in MEMORY_COLLECTIONS
        }

    def _build_chroma_client(self) -> Any:
        if self.config.chroma_mode == "jsonl" or chromadb is None:
            return None

        if self.config.chroma_mode == "http" or self.config.chroma_host:
            headers = {}
            if self.config.chroma_token:
                headers["Authorization"] = f"Bearer {self.config.chroma_token}"
            kwargs: Dict[str, Any] = {
                "host": self.config.chroma_host or "localhost",
                "port": self.config.chroma_port,
                "ssl": self.config.chroma_ssl,
                "headers": headers or None,
            }
            if self.config.chroma_tenant:
                kwargs["tenant"] = self.config.chroma_tenant
            if self.config.chroma_database:
                kwargs["database"] = self.config.chroma_database
            return chromadb.HttpClient(**kwargs)

        persist_path = Path(self.config.persist_dir)
        persist_path.mkdir(parents=True, exist_ok=True)
        kwargs = {"path": str(persist_path)}
        if self.config.chroma_tenant:
            kwargs["tenant"] = self.config.chroma_tenant
        if self.config.chroma_database:
            kwargs["database"] = self.config.chroma_database
        return chromadb.PersistentClient(**kwargs)

    def _get_collection(self, name: str) -> Any:
        collection_name = f"{self.config.collection_prefix}_{name}"
        if self.client is None:
            path = Path(self.config.persist_dir).parent / f"{collection_name}.jsonl"
            return _JsonlCollection(path)
        return self.client.get_or_create_collection(
            name=collection_name,
            metadata={"description": MEMORY_COLLECTIONS[name]},
        )

    def register_agent_mesh(self) -> str:
        """Record the sharding contract that lets 10,080 agents share memory."""

        return self._store(
            "cross_agent_learnings",
            {
                "summary": "YieldSwarm agents share Odysseus ChromaDB memory.",
                "agent_count_total": self.config.agent_count_total,
                "agents_per_shard": self.config.agents_per_shard,
                "shard_count": self.config.shard_count,
                "agent_id_pattern": "ys-shard-{shard_id:03d}-agent-{shard_index:03d}",
            },
            {
                "kind": "mesh_contract",
                "agent_count_total": self.config.agent_count_total,
                "agents_per_shard": self.config.agents_per_shard,
                "shard_count": self.config.shard_count,
            },
            event_id="mesh-contract-10080",
        )

    def record_mutation(
        self,
        *,
        agent_id: str,
        mutation: Dict[str, Any],
        outcome: Optional[Dict[str, Any]] = None,
        shard_id: Optional[int] = None,
        tags: Optional[Sequence[str]] = None,
    ) -> str:
        payload = {
            "agent_id": agent_id,
            "mutation": mutation,
            "outcome": outcome or {},
            "tags": list(tags or []),
        }
        return self._store(
            "agent_mutations",
            payload,
            {
                "kind": "agent_mutation",
                "agent_id": agent_id,
                "shard_id": shard_id,
                "mutation_type": mutation.get("type"),
                "agent_count_total": self.config.agent_count_total,
            },
        )

    def record_performance(
        self,
        *,
        agent_id: str,
        metric_name: str,
        metric_value: float,
        window: str = "instant",
        context: Optional[Dict[str, Any]] = None,
        shard_id: Optional[int] = None,
    ) -> str:
        payload = {
            "agent_id": agent_id,
            "metric_name": metric_name,
            "metric_value": metric_value,
            "window": window,
            "context": context or {},
        }
        return self._store(
            "performance_history",
            payload,
            {
                "kind": "performance_history",
                "agent_id": agent_id,
                "metric_name": metric_name,
                "metric_value": metric_value,
                "window": window,
                "shard_id": shard_id,
            },
        )

    def upsert_deity_identity(
        self,
        *,
        deity_id: str,
        name: str,
        role: str,
        authority: str,
        council_seat: Optional[int] = None,
        traits: Optional[Sequence[str]] = None,
    ) -> str:
        payload = {
            "deity_id": deity_id,
            "name": name,
            "role": role,
            "authority": authority,
            "council_seat": council_seat,
            "traits": list(traits or []),
        }
        return self._store(
            "deity_identities",
            payload,
            {
                "kind": "deity_identity",
                "deity_id": deity_id,
                "name": name,
                "role": role,
                "authority": authority,
                "council_seat": council_seat,
            },
            event_id=f"deity:{deity_id}",
        )

    def record_cross_agent_learning(
        self,
        *,
        source_agent_id: str,
        summary: str,
        applies_to: Optional[Sequence[str]] = None,
        confidence: float = 1.0,
        evidence: Optional[Dict[str, Any]] = None,
    ) -> str:
        payload = {
            "source_agent_id": source_agent_id,
            "summary": summary,
            "applies_to": list(applies_to or ["all_agents"]),
            "confidence": confidence,
            "evidence": evidence or {},
        }
        return self._store(
            "cross_agent_learnings",
            payload,
            {
                "kind": "cross_agent_learning",
                "source_agent_id": source_agent_id,
                "confidence": confidence,
            },
        )

    def recall(
        self,
        query_text: str,
        *,
        limit: int = 5,
        memory_types: Optional[Sequence[str]] = None,
        agent_id: Optional[str] = None,
        shard_id: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        """Retrieve shared memory records for any agent in the mesh."""

        collection_names = list(memory_types or MEMORY_COLLECTIONS.keys())
        results: List[Dict[str, Any]] = []
        for collection_name in collection_names:
            collection = self.collections[collection_name]
            raw = collection.query(query_texts=[query_text], n_results=limit)
            ids = raw.get("ids", [[]])[0]
            documents = raw.get("documents", [[]])[0]
            metadatas = raw.get("metadatas", [[]])[0]
            distances = raw.get("distances", [[]])[0] if raw.get("distances") else []
            for idx, item_id in enumerate(ids):
                metadata = metadatas[idx] if idx < len(metadatas) else {}
                if agent_id and metadata.get("agent_id") not in (agent_id, None):
                    continue
                if shard_id is not None and metadata.get("shard_id") not in (shard_id, None):
                    continue
                results.append(
                    {
                        "id": item_id,
                        "collection": collection_name,
                        "document": documents[idx] if idx < len(documents) else "",
                        "metadata": metadata,
                        "distance": distances[idx] if idx < len(distances) else None,
                    }
                )
        return results[:limit]

    def build_sync_payload(self, cursor: int = 0, limit: int = 1000) -> Dict[str, Any]:
        events = self._read_outbox()[cursor : cursor + limit]
        return {
            "node_id": self.config.node_id,
            "cursor": cursor + len(events),
            "generated_at": _utc_now(),
            "events": events,
        }

    def import_sync_payload(self, payload: Dict[str, Any]) -> int:
        imported = 0
        for event in payload.get("events", []):
            collection_name = event["collection"]
            if collection_name not in MEMORY_COLLECTIONS:
                continue
            if self._event_exists(collection_name, event["event_id"]):
                continue
            metadata = dict(event["metadata"])
            metadata["synced_from_node_id"] = payload.get("node_id", "unknown")
            self._store(
                collection_name,
                event["payload"],
                metadata,
                event_id=event["event_id"],
                created_at=event.get("created_at"),
            )
            imported += 1
        return imported

    def sync_with_peers(self, timeout_seconds: float = 5.0) -> List[Dict[str, Any]]:
        """Push local outbox events and import remote events from each peer."""

        reports: List[Dict[str, Any]] = []
        for peer_url in self.config.sync_peers:
            cursor_state = self._load_cursor_state(peer_url)
            payload = self.build_sync_payload(cursor_state.get("local_cursor", 0))
            payload["peer_cursor"] = cursor_state.get("remote_cursor", 0)
            body = _safe_json(payload).encode("utf-8")
            headers = {"Content-Type": "application/json"}
            if self.config.sync_token:
                headers["Authorization"] = f"Bearer {self.config.sync_token}"
            try:
                sync_request = request.Request(
                    peer_url.rstrip("/") + "/odysseus/memory/sync",
                    data=body,
                    headers=headers,
                    method="POST",
                )
                with request.urlopen(sync_request, timeout=timeout_seconds) as response:
                    remote_payload = json.loads(response.read().decode("utf-8"))
            except URLError as exc:
                reports.append(
                    {
                        "peer": peer_url,
                        "status": "error",
                        "error": str(exc),
                    }
                )
                continue

            imported = self.import_sync_payload(remote_payload)
            self._save_cursor_state(
                peer_url,
                {
                    "local_cursor": payload["cursor"],
                    "remote_cursor": remote_payload.get(
                        "cursor",
                        cursor_state.get("remote_cursor", 0),
                    ),
                },
            )
            reports.append(
                {
                    "peer": peer_url,
                    "status": "ok",
                    "pushed": len(payload["events"]),
                    "imported": imported,
                }
            )
        return reports

    def serve_sync_api(self, host: str = "0.0.0.0", port: int = 8097) -> None:
        """Serve the peer sync endpoint for Akash and multi-cloud workers."""

        memory = self

        class SyncHandler(BaseHTTPRequestHandler):
            def do_POST(self) -> None:  # noqa: N802 - required by BaseHTTPRequestHandler
                if self.path != "/odysseus/memory/sync":
                    self.send_error(404)
                    return
                if memory.config.sync_token:
                    expected = f"Bearer {memory.config.sync_token}"
                    if self.headers.get("Authorization") != expected:
                        self.send_error(401)
                        return
                length = int(self.headers.get("Content-Length", "0"))
                payload = json.loads(self.rfile.read(length).decode("utf-8"))
                imported = memory.import_sync_payload(payload)
                response_payload = memory.build_sync_payload(
                    cursor=int(payload.get("peer_cursor", 0))
                )
                response_payload["imported"] = imported
                response_body = _safe_json(response_payload).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(response_body)))
                self.end_headers()
                self.wfile.write(response_body)

            def log_message(self, format: str, *args: Any) -> None:
                return

        HTTPServer((host, port), SyncHandler).serve_forever()

    def _store(
        self,
        collection_name: str,
        payload: Dict[str, Any],
        metadata: Dict[str, Any],
        *,
        event_id: Optional[str] = None,
        created_at: Optional[str] = None,
    ) -> str:
        created_at = created_at or _utc_now()
        event_id = event_id or _stable_hash(
            [collection_name, payload, metadata, created_at, str(uuid.uuid4())]
        )
        if self._event_exists(collection_name, event_id):
            return event_id

        event_metadata = _clean_metadata(
            {
                **metadata,
                "event_id": event_id,
                "node_id": self.config.node_id,
                "created_at": created_at,
                "created_at_epoch": time.time(),
            }
        )
        document = self._document_for_payload(collection_name, payload)
        self.collections[collection_name].upsert(
            ids=[event_id],
            documents=[document],
            metadatas=[event_metadata],
        )
        self._append_outbox(
            {
                "event_id": event_id,
                "collection": collection_name,
                "payload": payload,
                "metadata": event_metadata,
                "document": document,
                "created_at": created_at,
            }
        )
        return event_id

    def _event_exists(self, collection_name: str, event_id: str) -> bool:
        existing = self.collections[collection_name].get(ids=[event_id])
        return bool(existing.get("ids"))

    def _document_for_payload(self, collection_name: str, payload: Dict[str, Any]) -> str:
        if collection_name == "agent_mutations":
            return (
                f"Agent {payload['agent_id']} mutation "
                f"{payload['mutation'].get('type', 'unknown')}: {_safe_json(payload)}"
            )
        if collection_name == "performance_history":
            return (
                f"Agent {payload['agent_id']} performance "
                f"{payload['metric_name']}={payload['metric_value']} "
                f"window={payload['window']}: {_safe_json(payload)}"
            )
        if collection_name == "deity_identities":
            return (
                f"Deity {payload['name']} ({payload['deity_id']}) "
                f"role={payload['role']} authority={payload['authority']}: "
                f"{_safe_json(payload)}"
            )
        return f"Cross-agent learning: {_safe_json(payload)}"

    def _append_outbox(self, event: Dict[str, Any]) -> None:
        with self.outbox_path.open("a", encoding="utf-8") as handle:
            handle.write(_safe_json(event) + "\n")

    def _read_outbox(self) -> List[Dict[str, Any]]:
        if not self.outbox_path.exists():
            return []
        events: List[Dict[str, Any]] = []
        with self.outbox_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if line:
                    events.append(json.loads(line))
        return events

    def _cursor_path(self, peer_url: str) -> Path:
        peer_hash = _stable_hash([peer_url])[:16]
        return self.cursor_dir / f"{peer_hash}.json"

    def _load_cursor_state(self, peer_url: str) -> Dict[str, int]:
        path = self._cursor_path(peer_url)
        if not path.exists():
            return {"local_cursor": 0, "remote_cursor": 0}
        return json.loads(path.read_text(encoding="utf-8"))

    def _save_cursor_state(self, peer_url: str, state: Dict[str, int]) -> None:
        self._cursor_path(peer_url).write_text(_safe_json(state), encoding="utf-8")


def get_memory() -> OdysseusMemory:
    return OdysseusMemory()


def record_driver_telemetry(record: Dict[str, Any]) -> None:
    """Fan-out signed Kairo driver telemetry into the Odysseus memory mesh."""
    memory = get_memory()
    payload = {
        "source": "kairo",
        "driver_id": record.get("driver_id"),
        "evm_address": record.get("evm_address"),
        "telemetry_id": record.get("telemetry_id"),
        "tree": record.get("tree"),
        "signed_at": record.get("signed_at"),
    }
    memory.record_cross_agent_learning(
        agent_id=f"kairo:{record.get('driver_id', 'unknown')}",
        topic="driver_telemetry",
        insight=_safe_json(payload),
        metadata=_clean_metadata(
            {
                "driver_id": record.get("driver_id"),
                "shard_id": (record.get("tree") or {}).get("shard_id"),
                "reward_weight": (record.get("tree") or {}).get("reward_weight"),
            }
        ),
    )


if __name__ == "__main__":
    memory = get_memory()
    memory.register_agent_mesh()
    reports = memory.sync_with_peers()
    print(
        "Odysseus memory active "
        f"node={memory.config.node_id} "
        f"collections={','.join(MEMORY_COLLECTIONS)} "
        f"sync_reports={_safe_json(reports)}"
    )
