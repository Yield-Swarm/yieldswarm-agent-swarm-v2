"""100 governance consensus models — Kimiclaw 9/14 threshold + internal gospel."""

from __future__ import annotations

import hashlib
import json
import os
import random
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Literal

from agents.governance.gospel import (
    CONSENSUS_THRESHOLD,
    COUNCIL_ROLES,
    COUNCIL_SEATS,
    GOVERNANCE_DELTA_TARGET,
    GOVERNANCE_MODEL_COUNT,
    GOSPEL_FUNDAMENTALS,
    GOSPEL_REGIONS,
    HEARTBEAT_SECONDS,
    LATENCY_GUARDRAIL_MS,
    TREASURY_SPLIT_BPS,
)

Vote = Literal["approve", "reject", "abstain"]


@dataclass(frozen=True)
class GovernanceModel:
    model_id: int
    council_seat: int
    deity_id: str
    deity_name: str
    role: str
    region: str
    fundamental: str
    latency_budget_ms: int
    heartbeat_seconds: int
    treasury_alignment: float

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ModelVote:
    model_id: int
    council_seat: int
    deity_id: str
    vote: Vote
    confidence: float
    gospel_score: float
    latency_ms: float
    rationale: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ConsensusReport:
    proposal: str
    model_count: int
    votes: list[ModelVote] = field(default_factory=list)
    approve_count: int = 0
    reject_count: int = 0
    abstain_count: int = 0
    council_approvals: int = 0
    threshold_met: bool = False
    governance_delta: float = 0.0
    autopilot_ready: bool = False
    kimiclaw_signature: str = ""
    generated_at: float = field(default_factory=time.time)

    def to_dict(self) -> dict[str, Any]:
        payload = {
            "proposal": self.proposal,
            "model_count": self.model_count,
            "consensus": {
                "threshold": f"{CONSENSUS_THRESHOLD[0]}/{CONSENSUS_THRESHOLD[1]}",
                "approve_count": self.approve_count,
                "reject_count": self.reject_count,
                "abstain_count": self.abstain_count,
                "council_approvals": self.council_approvals,
                "threshold_met": self.threshold_met,
            },
            "governance_delta": round(self.governance_delta, 4),
            "governance_delta_target": GOVERNANCE_DELTA_TARGET,
            "autopilot_ready": self.autopilot_ready,
            "kimiclaw_signature": self.kimiclaw_signature,
            "generated_at": self.generated_at,
            "votes": [vote.to_dict() for vote in self.votes],
            "gospel_invariants": {
                "treasury_split_bps": TREASURY_SPLIT_BPS,
                "latency_guardrail_ms": LATENCY_GUARDRAIL_MS,
                "heartbeat_seconds": HEARTBEAT_SECONDS,
            },
        }
        return payload


class GovernanceConsensusEngine:
    """Runs 100 gospel-weighted consensus models across the 14-Council."""

    def __init__(self, seed: int | None = None) -> None:
        self.seed = seed if seed is not None else int(os.getenv("GOVERNANCE_CONSENSUS_SEED", "100"))
        self.rng = random.Random(self.seed)

    def build_models(self, count: int = GOVERNANCE_MODEL_COUNT) -> list[GovernanceModel]:
        models: list[GovernanceModel] = []
        for model_id in range(1, count + 1):
            seat_index = (model_id - 1) % COUNCIL_SEATS
            deity_id, deity_name, role = COUNCIL_ROLES[seat_index]
            region = GOSPEL_REGIONS[(model_id - 1) % len(GOSPEL_REGIONS)]
            fundamental = GOSPEL_FUNDAMENTALS[(model_id - 1) % len(GOSPEL_FUNDAMENTALS)]

            # Gospel runtime knobs: proportion/grind/water/freshness modulate budgets.
            latency_budget = max(
                20,
                LATENCY_GUARDRAIL_MS - (model_id % 5) * 3 + (seat_index % 3) * 2,
            )
            heartbeat = HEARTBEAT_SECONDS + (model_id % 7) * 10 - (seat_index % 4) * 5
            treasury_alignment = min(
                1.0,
                0.72
                + (sum(TREASURY_SPLIT_BPS) / 10000.0) * 0.05
                + (model_id % 11) * 0.018
                - (seat_index % 5) * 0.01,
            )

            models.append(
                GovernanceModel(
                    model_id=model_id,
                    council_seat=seat_index + 1,
                    deity_id=deity_id,
                    deity_name=deity_name,
                    role=role,
                    region=region,
                    fundamental=fundamental,
                    latency_budget_ms=latency_budget,
                    heartbeat_seconds=max(300, heartbeat),
                    treasury_alignment=round(treasury_alignment, 4),
                )
            )
        return models

    def _is_gospel_proposal(self, proposal: str) -> bool:
        keywords = (
            "council",
            "wishlist",
            "integration",
            "governance",
            "kimiclaw",
            "sovereign",
            "wire",
            "bootstrap",
        )
        lowered = proposal.lower()
        return any(keyword in lowered for keyword in keywords)

    def _integration_boost(self) -> float:
        raw = os.getenv("COUNCIL_INTEGRATIONS_CONFIGURED", "")
        if raw.isdigit():
            return min(0.12, int(raw) * 0.015)
        return 0.0

    def _score_proposal(self, model: GovernanceModel, proposal: str) -> tuple[float, float]:
        """Return (gospel_score, simulated_latency_ms)."""
        digest = hashlib.sha256(f"{model.model_id}:{proposal}".encode()).hexdigest()
        base = int(digest[:8], 16) / 0xFFFFFFFF

        region_bias = {
            "latin_america": 0.04,
            "africa": 0.02,
            "asia_pacific": 0.03,
        }[model.region]
        fundamental_bias = {
            "proportion": 0.03,
            "grind": 0.02,
            "water": 0.01,
            "freshness": 0.04,
        }[model.fundamental]

        kimiclaw_boost = 0.08 if model.deity_id == "deity-001" else 0.0
        primary_boost = 0.05 if model.role == "primary_deity" else 0.02
        gospel_proposal_boost = 0.06 if self._is_gospel_proposal(proposal) else 0.0

        gospel_score = min(
            1.0,
            base * 0.50
            + model.treasury_alignment * 0.28
            + region_bias
            + fundamental_bias
            + kimiclaw_boost
            + primary_boost
            + gospel_proposal_boost
            + self._integration_boost(),
        )
        latency_ms = 18.0 + (1.0 - gospel_score) * 42.0 + self.rng.uniform(-4.0, 4.0)
        return round(gospel_score, 4), round(max(8.0, latency_ms), 2)

    def _vote(self, model: GovernanceModel, proposal: str) -> ModelVote:
        gospel_score, latency_ms = self._score_proposal(model, proposal)
        latency_ok = latency_ms <= model.latency_budget_ms
        treasury_ok = model.treasury_alignment >= 0.75
        gospel_proposal = self._is_gospel_proposal(proposal)

        if model.deity_id == "deity-001" and gospel_proposal and treasury_ok:
            vote: Vote = "approve"
            confidence = 0.99
            rationale = "Kimiclaw gospel lead — integration proposal preserves invariants"
        elif model.role == "primary_deity" and gospel_proposal and gospel_score >= 0.50 and latency_ok and treasury_ok:
            vote = "approve"
            confidence = min(0.96, gospel_score + 0.12)
            rationale = f"primary council approve ({model.region}/{model.fundamental})"
        elif model.role == "supporting_deity" and gospel_proposal and gospel_score >= 0.58 and latency_ok and treasury_ok:
            vote = "approve"
            confidence = min(0.92, gospel_score + 0.08)
            rationale = f"supporting council approve ({model.fundamental})"
        elif gospel_score >= 0.78 and latency_ok and treasury_ok:
            vote = "approve"
            confidence = min(0.99, gospel_score + 0.08)
            rationale = f"gospel-aligned ({model.region}/{model.fundamental}) within {latency_ms}ms"
        elif gospel_score < 0.45 or not treasury_ok:
            vote = "reject"
            confidence = min(0.95, 1.0 - gospel_score)
            rationale = "treasury or gospel invariant breach"
        else:
            vote = "abstain"
            confidence = 0.55
            rationale = "insufficient gospel confidence — abstain"

        return ModelVote(
            model_id=model.model_id,
            council_seat=model.council_seat,
            deity_id=model.deity_id,
            vote=vote,
            confidence=round(confidence, 4),
            gospel_score=gospel_score,
            latency_ms=latency_ms,
            rationale=rationale,
        )

    def run(
        self,
        proposal: str,
        *,
        model_count: int = GOVERNANCE_MODEL_COUNT,
    ) -> ConsensusReport:
        models = self.build_models(model_count)
        votes = [self._vote(model, proposal) for model in models]

        approve_count = sum(1 for v in votes if v.vote == "approve")
        reject_count = sum(1 for v in votes if v.vote == "reject")
        abstain_count = sum(1 for v in votes if v.vote == "abstain")

        # Council seat aggregation: seat approves if majority of its models approve.
        seat_votes: dict[int, list[Vote]] = {}
        for vote in votes:
            seat_votes.setdefault(vote.council_seat, []).append(vote.vote)

        council_approvals = 0
        for seat, seat_ballots in seat_votes.items():
            approvals = seat_ballots.count("approve")
            rejects = seat_ballots.count("reject")
            if approvals > rejects:
                council_approvals += 1
            elif approvals == rejects and seat == 1:
                # Kimiclaw tie-break for seat 1
                council_approvals += 1

        threshold_met = council_approvals >= CONSENSUS_THRESHOLD[0]
        mean_gospel = sum(v.gospel_score for v in votes) / len(votes)
        latency_compliance = sum(
            1 for v, m in zip(votes, models) if v.latency_ms <= m.latency_budget_ms
        ) / len(votes)
        governance_delta = min(
            1.0,
            mean_gospel * 0.55 + (council_approvals / COUNCIL_SEATS) * 0.30 + latency_compliance * 0.15,
        )
        autopilot_ready = threshold_met and governance_delta >= GOVERNANCE_DELTA_TARGET

        consensus_key = os.getenv("KIMICLAW_CONSENSUS_KEY", "kimiclaw-dev")
        signature_payload = f"{proposal}:{council_approvals}:{threshold_met}:{self.seed}"
        kimiclaw_signature = hashlib.sha256(
            f"{consensus_key}:{signature_payload}".encode()
        ).hexdigest()[:32]

        return ConsensusReport(
            proposal=proposal,
            model_count=model_count,
            votes=votes,
            approve_count=approve_count,
            reject_count=reject_count,
            abstain_count=abstain_count,
            council_approvals=council_approvals,
            threshold_met=threshold_met,
            governance_delta=round(governance_delta, 4),
            autopilot_ready=autopilot_ready,
            kimiclaw_signature=kimiclaw_signature,
        )


def run_governance_consensus(
    proposal: str,
    *,
    output_path: str | Path | None = None,
    model_count: int = GOVERNANCE_MODEL_COUNT,
    seed: int | None = None,
    configured_integrations: int | None = None,
) -> dict[str, Any]:
    """Execute 100-model consensus and optionally persist the report."""
    if configured_integrations is not None:
        os.environ["COUNCIL_INTEGRATIONS_CONFIGURED"] = str(configured_integrations)
    engine = GovernanceConsensusEngine(seed=seed)
    report = engine.run(proposal, model_count=model_count)
    payload = report.to_dict()

    path = Path(output_path or os.getenv("GOVERNANCE_CONSENSUS_OUTPUT", ".run/governance-consensus-report.json"))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    payload["output_path"] = str(path)
    return payload
