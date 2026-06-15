"""YieldSwarm Akash RTX 3090 model routing and workload placement.

The repository did not previously include a runnable Odysseus Cookbook
router, so this module provides the routing core that agents and API
adapters can share. It is intentionally dependency-free so it can run in
cron agents, Vercel/Azure bootstrap scripts, or local OpenClaw tooling.
"""

from __future__ import annotations

import hashlib
import json
import os
import time
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


RTX_3090_TOTAL_VRAM_GB = 24.0
DEFAULT_RTX_3090_RESERVED_VRAM_GB = 2.0


def _clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def _stable_unit_interval(value: str) -> float:
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()
    return int(digest[:8], 16) / 0xFFFFFFFF


@dataclass(frozen=True)
class ModelProfile:
    """A model option that can be placed on an Akash GPU worker."""

    model_id: str
    display_name: str
    tasks: Tuple[str, ...]
    vram_required_gb: float
    base_quality: float
    tokens_per_second: float
    emission_weight: float
    mutation_affinity: float
    min_free_vram_after_load_gb: float = 1.0
    max_replicas: int = 3

    @classmethod
    def from_mapping(cls, raw: Mapping[str, object]) -> "ModelProfile":
        return cls(
            model_id=str(raw["model_id"]),
            display_name=str(raw.get("display_name", raw["model_id"])),
            tasks=tuple(str(task) for task in raw.get("tasks", ())),
            vram_required_gb=float(raw["vram_required_gb"]),
            base_quality=float(raw.get("base_quality", 0.5)),
            tokens_per_second=float(raw.get("tokens_per_second", 1.0)),
            emission_weight=float(raw.get("emission_weight", 1.0)),
            mutation_affinity=float(raw.get("mutation_affinity", 0.5)),
            min_free_vram_after_load_gb=float(
                raw.get("min_free_vram_after_load_gb", 1.0)
            ),
            max_replicas=int(raw.get("max_replicas", 3)),
        )

    def supports(self, task: str) -> bool:
        return task in self.tasks or "general" in self.tasks

    def to_dict(self) -> Dict[str, object]:
        return {
            "model_id": self.model_id,
            "display_name": self.display_name,
            "tasks": list(self.tasks),
            "vram_required_gb": self.vram_required_gb,
            "base_quality": self.base_quality,
            "tokens_per_second": self.tokens_per_second,
            "emission_weight": self.emission_weight,
            "mutation_affinity": self.mutation_affinity,
            "min_free_vram_after_load_gb": self.min_free_vram_after_load_gb,
            "max_replicas": self.max_replicas,
        }


@dataclass
class ModelLoad:
    """Runtime model load state on a worker."""

    model_id: str
    vram_gb: float
    loaded_at: float = field(default_factory=time.time)
    last_used_at: float = field(default_factory=time.time)
    active_requests: int = 0

    def to_dict(self) -> Dict[str, object]:
        return {
            "model_id": self.model_id,
            "vram_gb": self.vram_gb,
            "loaded_at": self.loaded_at,
            "last_used_at": self.last_used_at,
            "active_requests": self.active_requests,
        }


@dataclass
class WorkerState:
    """A single Akash worker, expected to be backed by an RTX 3090."""

    worker_id: str
    provider_uri: str
    gpu_model: str = "RTX 3090"
    total_vram_gb: float = RTX_3090_TOTAL_VRAM_GB
    reserved_vram_gb: float = DEFAULT_RTX_3090_RESERVED_VRAM_GB
    queue_depth: int = 0
    active_requests: int = 0
    health_score: float = 1.0
    great_delta_signal: float = 0.0
    loaded_models: Dict[str, ModelLoad] = field(default_factory=dict)

    @classmethod
    def from_mapping(cls, raw: Mapping[str, object]) -> "WorkerState":
        loaded_models: Dict[str, ModelLoad] = {}
        for item in raw.get("loaded_models", ()) or ():
            if isinstance(item, str):
                # The caller can hydrate exact VRAM later from the model catalog.
                loaded_models[item] = ModelLoad(item, 0.0)
            elif isinstance(item, Mapping):
                load = ModelLoad(
                    model_id=str(item["model_id"]),
                    vram_gb=float(item.get("vram_gb", 0.0)),
                    active_requests=int(item.get("active_requests", 0)),
                )
                loaded_models[load.model_id] = load

        return cls(
            worker_id=str(raw["worker_id"]),
            provider_uri=str(raw.get("provider_uri", "")),
            gpu_model=str(raw.get("gpu_model", "RTX 3090")),
            total_vram_gb=float(raw.get("total_vram_gb", RTX_3090_TOTAL_VRAM_GB)),
            reserved_vram_gb=float(
                raw.get("reserved_vram_gb", DEFAULT_RTX_3090_RESERVED_VRAM_GB)
            ),
            queue_depth=int(raw.get("queue_depth", 0)),
            active_requests=int(raw.get("active_requests", 0)),
            health_score=float(raw.get("health_score", 1.0)),
            great_delta_signal=float(raw.get("great_delta_signal", 0.0)),
            loaded_models=loaded_models,
        )

    @property
    def used_vram_gb(self) -> float:
        return sum(load.vram_gb for load in self.loaded_models.values())

    @property
    def usable_vram_gb(self) -> float:
        return max(0.0, self.total_vram_gb - self.reserved_vram_gb)

    @property
    def free_vram_gb(self) -> float:
        return max(0.0, self.usable_vram_gb - self.used_vram_gb)

    @property
    def workload_pressure(self) -> float:
        return _clamp((self.queue_depth + self.active_requests) / 12.0)

    def has_model(self, model_id: str) -> bool:
        return model_id in self.loaded_models

    def can_fit(self, model: ModelProfile) -> bool:
        if self.has_model(model.model_id):
            return True
        return (
            self.free_vram_gb - model.vram_required_gb
            >= model.min_free_vram_after_load_gb
        )

    def to_dict(self) -> Dict[str, object]:
        return {
            "worker_id": self.worker_id,
            "provider_uri": self.provider_uri,
            "gpu_model": self.gpu_model,
            "total_vram_gb": self.total_vram_gb,
            "reserved_vram_gb": self.reserved_vram_gb,
            "used_vram_gb": self.used_vram_gb,
            "free_vram_gb": self.free_vram_gb,
            "queue_depth": self.queue_depth,
            "active_requests": self.active_requests,
            "health_score": self.health_score,
            "great_delta_signal": self.great_delta_signal,
            "loaded_models": [
                load.to_dict() for load in self.loaded_models.values()
            ],
        }


@dataclass(frozen=True)
class RouteDecision:
    """The selected model, target worker, and lifecycle action."""

    model_id: str
    worker_id: str
    provider_uri: str
    score: float
    action: str
    reason: str
    unload_before_load: Tuple[str, ...] = ()

    def to_dict(self) -> Dict[str, object]:
        return {
            "model_id": self.model_id,
            "worker_id": self.worker_id,
            "provider_uri": self.provider_uri,
            "score": round(self.score, 4),
            "action": self.action,
            "reason": self.reason,
            "unload_before_load": list(self.unload_before_load),
        }


class GreatDeltaEmissionLogic:
    """Scores how much a route contributes to Great Delta emissions.

    The score combines the worker's current emission signal with model
    emission efficiency and request priority. Agents can feed observed
    output value back into ``great_delta_signal`` through the worker API.
    """

    def score(
        self,
        *,
        task: str,
        model: ModelProfile,
        worker: WorkerState,
        priority: float,
    ) -> float:
        task_bias = {
            "agent": 0.08,
            "reasoning": 0.06,
            "coding": 0.04,
            "chat": 0.02,
        }.get(task, 0.0)
        pressure_penalty = worker.workload_pressure * 0.18
        raw = (
            0.45
            + model.emission_weight * 0.28
            + worker.great_delta_signal * 0.18
            + _clamp(priority) * 0.11
            + task_bias
            - pressure_penalty
        )
        return _clamp(raw)


class AgentMutationScorer:
    """Scores model fit for agent mutation and exploration loops."""

    def score(
        self,
        *,
        agent_id: Optional[str],
        model: ModelProfile,
        task: str,
        override_score: Optional[float] = None,
    ) -> float:
        if override_score is not None:
            base = _clamp(float(override_score))
        elif agent_id:
            base = _stable_unit_interval(f"{agent_id}:{task}:{model.model_id}")
        else:
            base = 0.5

        exploration = abs(model.mutation_affinity - base)
        return _clamp((model.mutation_affinity * 0.68) + ((1.0 - exploration) * 0.32))


class YieldSwarmModelRouter:
    """Routes requests to the best available model across the RTX 3090 fleet."""

    def __init__(
        self,
        workers: Sequence[WorkerState],
        models: Sequence[ModelProfile],
        emission_logic: Optional[GreatDeltaEmissionLogic] = None,
        mutation_scorer: Optional[AgentMutationScorer] = None,
    ) -> None:
        self.workers: Dict[str, WorkerState] = {
            worker.worker_id: worker for worker in workers
        }
        self.models: Dict[str, ModelProfile] = {
            model.model_id: model for model in models
        }
        self.emission_logic = emission_logic or GreatDeltaEmissionLogic()
        self.mutation_scorer = mutation_scorer or AgentMutationScorer()
        self._hydrate_loaded_model_vram()

    @classmethod
    def from_env(cls) -> "YieldSwarmModelRouter":
        return cls(
            workers=load_workers_from_env(),
            models=load_models_from_env(),
        )

    def recommend(
        self,
        *,
        task: str = "chat",
        agent_id: Optional[str] = None,
        priority: float = 0.5,
        mutation_score: Optional[float] = None,
    ) -> RouteDecision:
        candidates = self._rank_candidates(
            task=task,
            agent_id=agent_id,
            priority=priority,
            mutation_score=mutation_score,
        )
        if not candidates:
            raise ValueError(f"No Akash RTX 3090 route can serve task '{task}'")
        return candidates[0]

    def route_request(
        self,
        *,
        task: str = "chat",
        agent_id: Optional[str] = None,
        priority: float = 0.5,
        mutation_score: Optional[float] = None,
        autoload: bool = True,
    ) -> RouteDecision:
        decision = self.recommend(
            task=task,
            agent_id=agent_id,
            priority=priority,
            mutation_score=mutation_score,
        )
        if autoload and decision.action in {"load", "evict_then_load"}:
            for model_id in decision.unload_before_load:
                self.unload_model(model_id=model_id, worker_id=decision.worker_id)
            self.load_model(model_id=decision.model_id, worker_id=decision.worker_id)

        worker = self.workers[decision.worker_id]
        worker.queue_depth = max(0, worker.queue_depth - 1)
        worker.active_requests += 1
        if decision.model_id in worker.loaded_models:
            worker.loaded_models[decision.model_id].active_requests += 1
            worker.loaded_models[decision.model_id].last_used_at = time.time()
        return decision

    def complete_request(self, *, worker_id: str, model_id: str) -> None:
        worker = self.workers[worker_id]
        worker.active_requests = max(0, worker.active_requests - 1)
        if model_id in worker.loaded_models:
            load = worker.loaded_models[model_id]
            load.active_requests = max(0, load.active_requests - 1)
            load.last_used_at = time.time()

    def load_model(self, *, model_id: str, worker_id: Optional[str] = None) -> RouteDecision:
        model = self._model(model_id)
        if worker_id:
            worker = self._worker(worker_id)
            unloads = self._evictions_needed(worker, model)
            for unload_model_id in unloads:
                self.unload_model(model_id=unload_model_id, worker_id=worker.worker_id)
            if not worker.can_fit(model):
                raise ValueError(
                    f"Worker {worker.worker_id} cannot fit {model_id} with "
                    f"{worker.free_vram_gb:.1f}GB free"
                )
            self._attach_model(worker, model)
            return RouteDecision(
                model_id=model.model_id,
                worker_id=worker.worker_id,
                provider_uri=worker.provider_uri,
                score=1.0,
                action="loaded",
                reason="explicit load request",
                unload_before_load=tuple(unloads),
            )

        decision = self.recommend(task=model.tasks[0] if model.tasks else "general")
        if decision.model_id != model_id:
            target_worker = self._best_worker_for_model(model)
            if target_worker is None:
                raise ValueError(f"No worker can fit {model_id}")
            decision = RouteDecision(
                model_id=model.model_id,
                worker_id=target_worker.worker_id,
                provider_uri=target_worker.provider_uri,
                score=1.0,
                action="load",
                reason="explicit load request selected best available worker",
                unload_before_load=tuple(self._evictions_needed(target_worker, model)),
            )

        for unload_model_id in decision.unload_before_load:
            self.unload_model(model_id=unload_model_id, worker_id=decision.worker_id)
        self._attach_model(self.workers[decision.worker_id], model)
        return decision

    def unload_model(self, *, model_id: str, worker_id: Optional[str] = None) -> Dict[str, object]:
        workers = [self._worker(worker_id)] if worker_id else self.workers.values()
        unloaded: List[str] = []
        for worker in workers:
            load = worker.loaded_models.get(model_id)
            if not load:
                continue
            if load.active_requests > 0:
                raise ValueError(
                    f"Cannot unload {model_id} from {worker.worker_id}; "
                    f"{load.active_requests} request(s) active"
                )
            del worker.loaded_models[model_id]
            unloaded.append(worker.worker_id)
        return {"model_id": model_id, "unloaded_from": unloaded}

    def rebalance(self, workload: Mapping[str, object]) -> Dict[str, object]:
        """Load and evict models to match current swarm workload.

        ``workload`` accepts ``task_weights`` such as
        ``{"chat": 0.6, "coding": 0.4}`` and optional ``worker_pressure`` keyed
        by worker id. High pressure workers unload idle low-value models; high
        weight tasks get their top route pre-loaded.
        """

        for worker_id, pressure in workload.get("worker_pressure", {}).items():
            if worker_id in self.workers:
                self.workers[worker_id].queue_depth = int(float(pressure) * 12)

        actions: List[Dict[str, object]] = []
        task_weights = workload.get("task_weights", {})
        if isinstance(task_weights, Mapping):
            ranked_tasks = sorted(
                ((str(task), float(weight)) for task, weight in task_weights.items()),
                key=lambda item: item[1],
                reverse=True,
            )
            for task, weight in ranked_tasks:
                if weight <= 0:
                    continue
                decision = self.route_request(task=task, priority=min(weight, 1.0))
                self.complete_request(
                    worker_id=decision.worker_id,
                    model_id=decision.model_id,
                )
                actions.append({"task": task, **decision.to_dict()})

        for worker in self.workers.values():
            if worker.workload_pressure < 0.75:
                continue
            idle_loads = sorted(
                (
                    load
                    for load in worker.loaded_models.values()
                    if load.active_requests == 0
                ),
                key=lambda load: load.last_used_at,
            )
            while worker.workload_pressure >= 0.75 and len(idle_loads) > 1:
                evicted = idle_loads.pop(0)
                del worker.loaded_models[evicted.model_id]
                worker.queue_depth = max(0, worker.queue_depth - 1)
                actions.append(
                    {
                        "action": "pressure_unload",
                        "worker_id": worker.worker_id,
                        "model_id": evicted.model_id,
                    }
                )

        return {"actions": actions, "workers": self.workers_snapshot()}

    def routes_for_task(self, task: str) -> List[Dict[str, object]]:
        return [
            decision.to_dict()
            for decision in self._rank_candidates(
                task=task,
                agent_id=None,
                priority=0.5,
                mutation_score=None,
            )
        ]

    def workers_snapshot(self) -> List[Dict[str, object]]:
        return [worker.to_dict() for worker in self.workers.values()]

    def model_catalog_snapshot(self) -> List[Dict[str, object]]:
        return [model.to_dict() for model in self.models.values()]

    def _rank_candidates(
        self,
        *,
        task: str,
        agent_id: Optional[str],
        priority: float,
        mutation_score: Optional[float],
    ) -> List[RouteDecision]:
        decisions: List[RouteDecision] = []
        for model in self.models.values():
            if not model.supports(task):
                continue
            replica_count = sum(
                1 for worker in self.workers.values() if worker.has_model(model.model_id)
            )
            if replica_count >= model.max_replicas:
                workers = [
                    worker
                    for worker in self.workers.values()
                    if worker.has_model(model.model_id)
                ]
            else:
                workers = list(self.workers.values())

            for worker in workers:
                evictions = self._evictions_needed(worker, model)
                if not worker.can_fit(model) and not evictions:
                    continue
                if not worker.can_fit(model) and not self._can_fit_after_evictions(
                    worker, model, evictions
                ):
                    continue

                is_loaded = worker.has_model(model.model_id)
                action = "serve" if is_loaded else "load"
                if evictions and not is_loaded:
                    action = "evict_then_load"

                emission = self.emission_logic.score(
                    task=task,
                    model=model,
                    worker=worker,
                    priority=priority,
                )
                mutation = self.mutation_scorer.score(
                    agent_id=agent_id,
                    model=model,
                    task=task,
                    override_score=mutation_score,
                )
                capacity = 1.0 - worker.workload_pressure
                headroom_after_load = (
                    worker.free_vram_gb
                    if is_loaded
                    else worker.free_vram_gb - model.vram_required_gb
                )
                headroom = _clamp(headroom_after_load / max(worker.usable_vram_gb, 1.0))
                throughput = _clamp(model.tokens_per_second / 64.0)
                task_specificity = 1.0 if task in model.tasks else 0.0
                loaded_bonus = 0.08 if is_loaded else 0.0
                load_penalty = 0.04 if not is_loaded else 0.0
                eviction_penalty = 0.05 * len(evictions)

                score = (
                    model.base_quality * 0.34
                    + throughput * 0.12
                    + capacity * 0.17
                    + headroom * 0.13
                    + emission * 0.15
                    + mutation * 0.09
                    + task_specificity * 0.08
                    + loaded_bonus
                    - load_penalty
                    - eviction_penalty
                )
                decisions.append(
                    RouteDecision(
                        model_id=model.model_id,
                        worker_id=worker.worker_id,
                        provider_uri=worker.provider_uri,
                        score=score,
                        action=action,
                        reason=(
                            f"{model.display_name} scored for {task} with "
                            f"{worker.free_vram_gb:.1f}GB free VRAM"
                        ),
                        unload_before_load=tuple(evictions),
                    )
                )
        return sorted(decisions, key=lambda decision: decision.score, reverse=True)

    def _evictions_needed(self, worker: WorkerState, model: ModelProfile) -> List[str]:
        if worker.has_model(model.model_id) or worker.can_fit(model):
            return []

        free_vram = worker.free_vram_gb
        evictions: List[str] = []
        idle_loads = sorted(
            (
                load
                for load in worker.loaded_models.values()
                if load.active_requests == 0
            ),
            key=lambda load: (load.last_used_at, load.vram_gb),
        )
        for load in idle_loads:
            evictions.append(load.model_id)
            free_vram += load.vram_gb
            if free_vram - model.vram_required_gb >= model.min_free_vram_after_load_gb:
                return evictions
        return []

    def _can_fit_after_evictions(
        self, worker: WorkerState, model: ModelProfile, evictions: Sequence[str]
    ) -> bool:
        reclaimed = sum(
            worker.loaded_models[model_id].vram_gb
            for model_id in evictions
            if model_id in worker.loaded_models
        )
        return (
            worker.free_vram_gb + reclaimed - model.vram_required_gb
            >= model.min_free_vram_after_load_gb
        )

    def _best_worker_for_model(self, model: ModelProfile) -> Optional[WorkerState]:
        candidates = [
            worker
            for worker in self.workers.values()
            if worker.can_fit(model)
            or self._can_fit_after_evictions(
                worker, model, self._evictions_needed(worker, model)
            )
        ]
        if not candidates:
            return None
        return sorted(
            candidates,
            key=lambda worker: (worker.free_vram_gb, worker.health_score),
            reverse=True,
        )[0]

    def _attach_model(self, worker: WorkerState, model: ModelProfile) -> None:
        if model.model_id not in worker.loaded_models:
            worker.loaded_models[model.model_id] = ModelLoad(
                model_id=model.model_id,
                vram_gb=model.vram_required_gb,
            )

    def _hydrate_loaded_model_vram(self) -> None:
        for worker in self.workers.values():
            for model_id, load in worker.loaded_models.items():
                if load.vram_gb <= 0 and model_id in self.models:
                    load.vram_gb = self.models[model_id].vram_required_gb

    def _model(self, model_id: str) -> ModelProfile:
        try:
            return self.models[model_id]
        except KeyError as exc:
            raise ValueError(f"Unknown model_id '{model_id}'") from exc

    def _worker(self, worker_id: str) -> WorkerState:
        try:
            return self.workers[worker_id]
        except KeyError as exc:
            raise ValueError(f"Unknown worker_id '{worker_id}'") from exc


def default_model_catalog() -> List[ModelProfile]:
    """Models sized to run well on 24GB RTX 3090 workers."""

    return [
        ModelProfile(
            model_id="phi-3.5-mini-instruct-q6",
            display_name="Phi 3.5 Mini Instruct Q6",
            tasks=("chat", "summarize", "tool", "general"),
            vram_required_gb=4.5,
            base_quality=0.70,
            tokens_per_second=72.0,
            emission_weight=0.78,
            mutation_affinity=0.48,
            max_replicas=6,
        ),
        ModelProfile(
            model_id="mistral-7b-instruct-q5",
            display_name="Mistral 7B Instruct Q5",
            tasks=("chat", "summarize", "agent", "general"),
            vram_required_gb=7.0,
            base_quality=0.78,
            tokens_per_second=58.0,
            emission_weight=0.84,
            mutation_affinity=0.58,
            max_replicas=5,
        ),
        ModelProfile(
            model_id="llama-3.1-8b-instruct-q5",
            display_name="Llama 3.1 8B Instruct Q5",
            tasks=("chat", "coding", "agent", "general"),
            vram_required_gb=8.0,
            base_quality=0.82,
            tokens_per_second=52.0,
            emission_weight=0.88,
            mutation_affinity=0.64,
            max_replicas=5,
        ),
        ModelProfile(
            model_id="qwen2.5-coder-7b-q5",
            display_name="Qwen2.5 Coder 7B Q5",
            tasks=("coding", "tool", "agent"),
            vram_required_gb=8.5,
            base_quality=0.84,
            tokens_per_second=48.0,
            emission_weight=0.90,
            mutation_affinity=0.72,
            max_replicas=4,
        ),
        ModelProfile(
            model_id="deepseek-r1-distill-llama-8b-q5",
            display_name="DeepSeek R1 Distill Llama 8B Q5",
            tasks=("reasoning", "coding", "agent"),
            vram_required_gb=9.5,
            base_quality=0.86,
            tokens_per_second=40.0,
            emission_weight=0.94,
            mutation_affinity=0.78,
            max_replicas=4,
        ),
        ModelProfile(
            model_id="mixtral-8x7b-instruct-q4",
            display_name="Mixtral 8x7B Instruct Q4",
            tasks=("chat", "reasoning", "agent"),
            vram_required_gb=20.5,
            base_quality=0.90,
            tokens_per_second=18.0,
            emission_weight=0.98,
            mutation_affinity=0.82,
            min_free_vram_after_load_gb=0.8,
            max_replicas=2,
        ),
    ]


def default_workers() -> List[WorkerState]:
    count = int(os.getenv("YIELDSWARM_RTX3090_WORKER_COUNT", "3"))
    return [
        WorkerState(
            worker_id=f"akash-rtx3090-{index}",
            provider_uri=os.getenv(
                f"YIELDSWARM_AKASH_WORKER_{index}_URI",
                f"http://akash-rtx3090-{index}.local:8000",
            ),
            great_delta_signal=0.2 + (index * 0.05),
        )
        for index in range(1, count + 1)
    ]


def load_models_from_env() -> List[ModelProfile]:
    raw = os.getenv("YIELDSWARM_MODEL_CATALOG")
    if not raw:
        return default_model_catalog()
    data = json.loads(raw)
    return [ModelProfile.from_mapping(item) for item in data]


def load_workers_from_env() -> List[WorkerState]:
    raw = os.getenv("YIELDSWARM_AKASH_WORKERS")
    if not raw:
        return default_workers()
    data = json.loads(raw)
    return [WorkerState.from_mapping(item) for item in data]


def summarize_recommendations(
    router: YieldSwarmModelRouter,
    tasks: Iterable[str] = ("chat", "coding", "reasoning", "agent"),
) -> Dict[str, object]:
    return {
        "recommendations": {
            task: router.recommend(task=task).to_dict() for task in tasks
        },
        "workers": router.workers_snapshot(),
        "models": router.model_catalog_snapshot(),
    }
