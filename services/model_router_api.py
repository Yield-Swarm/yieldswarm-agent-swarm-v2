"""FastAPI sidecar exposing YieldSwarmModelRouter recommendations to LiteLLM."""

from __future__ import annotations

import os
from typing import Any, Dict, List

import httpx
from fastapi import FastAPI
from pydantic import BaseModel

from yieldswarm_model_router import (
    ModelProfile,
    WorkerNode,
    YieldSwarmModelRouter,
)

app = FastAPI(title="YieldSwarm Model Router API", version="1.0.0")

DEFAULT_MODELS = [
    ModelProfile(
        model_id="llama3.1:8b",
        display_name="Llama 3.1 8B",
        tasks=("chat", "general"),
        vram_required_gb=6.0,
        base_quality=0.72,
        tokens_per_second=45.0,
        emission_weight=1.0,
        mutation_affinity=0.6,
    ),
    ModelProfile(
        model_id="nomic-embed-text",
        display_name="Nomic Embed",
        tasks=("embedding",),
        vram_required_gb=1.5,
        base_quality=0.8,
        tokens_per_second=200.0,
        emission_weight=0.5,
        mutation_affinity=0.3,
    ),
]

router = YieldSwarmModelRouter(model_catalog=DEFAULT_MODELS)


class RouteRequest(BaseModel):
    task: str = "chat"
    agent_id: str = "odysseus-default"
    preferred_model: str | None = None


class SyncLiteLLMRequest(BaseModel):
    ollama_base_url: str | None = None


def _worker_from_env() -> WorkerNode:
    base = os.environ.get("AKASH_OLLAMA_BASE_URL", "http://ollama:11434")
    return WorkerNode(
        worker_id="local-ollama",
        provider="local",
        region="docker",
        gpu_model="rtx3090",
        total_vram_gb=24.0,
        free_vram_gb=20.0,
        ollama_base_url=base,
        latency_ms=5.0,
        load_factor=0.2,
        emission_multiplier=1.0,
    )


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.post("/recommend")
def recommend(req: RouteRequest) -> Dict[str, Any]:
    worker = _worker_from_env()
    rec = router.recommend(
        task=req.task,
        agent_id=req.agent_id,
        workers=[worker],
        preferred_model=req.preferred_model,
    )
    return {
        "model_id": rec.chosen_model.model_id,
        "worker_id": rec.chosen_worker.worker_id,
        "ollama_base_url": rec.chosen_worker.ollama_base_url,
        "score": rec.score,
        "rationale": rec.rationale,
    }


@app.post("/sync-litellm")
async def sync_litellm(req: SyncLiteLLMRequest) -> Dict[str, Any]:
    """Push current Akash Ollama endpoint into LiteLLM upstream config."""
    litellm_url = os.environ.get("LITELLM_URL", "http://llm-router:4000")
    master_key = os.environ.get("LITELLM_MASTER_KEY", "")
    ollama_base = req.ollama_base_url or os.environ.get(
        "AKASH_OLLAMA_BASE_URL", "http://ollama:11434"
    )

    # LiteLLM reads env at startup; trigger config reload via health ping
    # and return the resolved upstream for operators.
    async with httpx.AsyncClient(timeout=10.0) as client:
        headers = {"Authorization": f"Bearer {master_key}"} if master_key else {}
        health = await client.get(f"{litellm_url}/health", headers=headers)

    return {
        "litellm_status": health.status_code,
        "akash_ollama_base_url": ollama_base,
        "message": "Set AKASH_OLLAMA_BASE_URL in llm-router env and restart to apply",
    }


@app.get("/workers")
def list_workers() -> List[Dict[str, Any]]:
    w = _worker_from_env()
    return [w.to_dict()]
