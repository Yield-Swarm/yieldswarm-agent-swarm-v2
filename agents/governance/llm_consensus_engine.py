"""Live LLM consensus — council voters choose the next operational step."""

from __future__ import annotations

import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any, Literal

from agents.governance.consensus_engine import run_governance_consensus
from agents.governance.gospel import CONSENSUS_THRESHOLD, COUNCIL_SEATS

Vote = Literal["approve", "reject", "abstain"]

REPO_ROOT = Path(__file__).resolve().parents[2]
VOTERS_PATH = REPO_ROOT / "config" / "governance" / "llm_voters.json"
DEFAULT_OUTPUT = REPO_ROOT / ".run" / "llm-consensus-report.json"

SYSTEM_PROMPT = """You are a council seat on the YieldSwarm 14-Council governance mesh.
You must vote on the NEXT STEP for the swarm based on context and options.

Respond with ONLY valid JSON (no markdown fences):
{
  "vote": "approve" | "reject" | "abstain",
  "chosen_option_id": "<id from options list or null>",
  "confidence": 0.0 to 1.0,
  "rationale": "one or two sentences"
}

Rules:
- approve only if the chosen option preserves treasury 50/30/15/5 and security invariants
- reject if the step risks capital, breaks isolation, or lacks clear ROI
- abstain if context is insufficient
- chosen_option_id MUST be one of the provided option ids when vote is approve
"""


@dataclass
class VoterSpec:
    id: str
    display_name: str
    provider: str
    model: str
    env_key: str
    council_seat: int
    weight: float
    base_url: str = ""
    api_key: str = ""
    optional: bool = False
    always_on: bool = False


@dataclass
class LlmVote:
    voter_id: str
    display_name: str
    council_seat: int
    provider: str
    model: str
    vote: Vote
    chosen_option_id: str | None
    confidence: float
    rationale: str
    latency_ms: float
    live: bool
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class LlmConsensusReport:
    mode: str
    context: str
    options: list[dict[str, Any]]
    votes: list[LlmVote] = field(default_factory=list)
    live_voter_count: int = 0
    simulated_voter_count: int = 0
    council_approvals: int = 0
    threshold_met: bool = False
    winning_option_id: str | None = None
    winning_option_label: str | None = None
    option_scores: dict[str, float] = field(default_factory=dict)
    kimiclaw_signature: str = ""
    generated_at: float = field(default_factory=time.time)

    def to_dict(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "context": self.context,
            "options": self.options,
            "consensus": {
                "threshold": f"{CONSENSUS_THRESHOLD[0]}/{CONSENSUS_THRESHOLD[1]}",
                "council_approvals": self.council_approvals,
                "threshold_met": self.threshold_met,
                "winning_option_id": self.winning_option_id,
                "winning_option_label": self.winning_option_label,
                "option_scores": self.option_scores,
            },
            "live_voter_count": self.live_voter_count,
            "simulated_voter_count": self.simulated_voter_count,
            "votes": [v.to_dict() for v in self.votes],
            "kimiclaw_signature": self.kimiclaw_signature,
            "generated_at": self.generated_at,
        }


def _load_voters_config() -> dict[str, Any]:
    if not VOTERS_PATH.exists():
        return {"voters": []}
    return json.loads(VOTERS_PATH.read_text(encoding="utf-8"))


def _resolve_voter(raw: dict[str, Any]) -> VoterSpec | None:
    always_on = bool(raw.get("always_on"))
    env_key = str(raw.get("env_key") or "")
    api_key = os.getenv(env_key) if env_key else ""
    if raw.get("api_key_fallback_env") and not api_key:
        api_key = os.getenv(str(raw["api_key_fallback_env"]), "")

    if not always_on and not api_key and raw.get("provider") != "gospel_sim":
        if raw.get("optional"):
            return None
        if env_key and not os.getenv(env_key):
            return None

    model = str(raw.get("model") or "")
    if not model and raw.get("model_env"):
        model = os.getenv(str(raw["model_env"]), str(raw.get("model_default", "")))

    base_url = ""
    if raw.get("base_url_env"):
        base_url = os.getenv(str(raw["base_url_env"]), str(raw.get("default_base_url", "")))
    base_url = base_url.rstrip("/")

    if raw.get("provider") == "openai" and not base_url and not always_on:
        if not api_key and not raw.get("optional"):
            return None

    return VoterSpec(
        id=str(raw["id"]),
        display_name=str(raw.get("display_name", raw["id"])),
        provider=str(raw["provider"]),
        model=model or "unknown",
        env_key=env_key,
        council_seat=int(raw.get("council_seat", 1)),
        weight=float(raw.get("weight", 1.0)),
        base_url=base_url,
        api_key=api_key or "local",
        optional=bool(raw.get("optional")),
        always_on=always_on,
    )


def list_active_voters() -> list[dict[str, Any]]:
    cfg = _load_voters_config()
    active: list[dict[str, Any]] = []
    for raw in cfg.get("voters", []):
        spec = _resolve_voter(raw)
        if spec:
            active.append(
                {
                    "id": spec.id,
                    "display_name": spec.display_name,
                    "provider": spec.provider,
                    "model": spec.model,
                    "council_seat": spec.council_seat,
                    "weight": spec.weight,
                    "configured": spec.provider == "gospel_sim" or bool(spec.api_key and spec.api_key != "local"),
                }
            )
    return active


def _build_user_prompt(context: str, options: list[dict[str, Any]], proposal: str | None) -> str:
    lines = [
        "## Context",
        context.strip(),
        "",
        "## Candidate next steps",
    ]
    for opt in options:
        lines.append(f"- id: {opt['id']} | label: {opt.get('label', opt['id'])}")
        if opt.get("detail"):
            lines.append(f"  detail: {opt['detail']}")
    if proposal:
        lines.extend(["", "## Proposal under review", proposal.strip()])
    lines.append("")
    lines.append("Return JSON vote for the best next step.")
    return "\n".join(lines)


def _parse_vote_json(text: str) -> dict[str, Any]:
    text = text.strip()
    fence = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if fence:
        text = fence.group(1).strip()
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        text = text[start : end + 1]
    data = json.loads(text)
    vote = str(data.get("vote", "abstain")).lower()
    if vote not in {"approve", "reject", "abstain"}:
        vote = "abstain"
    chosen = data.get("chosen_option_id")
    if chosen is not None:
        chosen = str(chosen)
    confidence = float(data.get("confidence", 0.5))
    confidence = max(0.0, min(1.0, confidence))
    rationale = str(data.get("rationale", ""))[:500]
    return {
        "vote": vote,
        "chosen_option_id": chosen,
        "confidence": confidence,
        "rationale": rationale,
    }


def _http_post_json(url: str, headers: dict[str, str], payload: dict[str, Any], timeout: int) -> dict[str, Any]:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _call_openai_compatible(spec: VoterSpec, user_prompt: str, timeout: int) -> str:
    url = f"{spec.base_url}/chat/completions"
    payload = {
        "model": spec.model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.2,
        "max_tokens": 400,
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {spec.api_key}",
    }
    data = _http_post_json(url, headers, payload, timeout)
    return data["choices"][0]["message"]["content"]


def _call_anthropic(spec: VoterSpec, user_prompt: str, timeout: int) -> str:
    url = "https://api.anthropic.com/v1/messages"
    payload = {
        "model": spec.model,
        "max_tokens": 400,
        "system": SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": user_prompt}],
    }
    headers = {
        "Content-Type": "application/json",
        "x-api-key": spec.api_key,
        "anthropic-version": "2023-06-01",
    }
    data = _http_post_json(url, headers, payload, timeout)
    return data["content"][0]["text"]


def _call_gemini(spec: VoterSpec, user_prompt: str, timeout: int) -> str:
    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{spec.model}:generateContent?key={spec.api_key}"
    )
    payload = {
        "contents": [{"parts": [{"text": f"{SYSTEM_PROMPT}\n\n{user_prompt}"}]}],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 400},
    }
    headers = {"Content-Type": "application/json"}
    data = _http_post_json(url, headers, payload, timeout)
    return data["candidates"][0]["content"]["parts"][0]["text"]


def _call_gospel_sim(spec: VoterSpec, context: str, options: list[dict[str, Any]], proposal: str | None) -> LlmVote:
    text = proposal or context
    gospel = run_governance_consensus(text, model_count=100)
    threshold_met = gospel["consensus"]["threshold_met"]
    vote: Vote = "approve" if threshold_met else "abstain"
    chosen = options[0]["id"] if options and vote == "approve" else None
    if options and vote == "approve" and len(options) > 1:
        idx = gospel["consensus"]["council_approvals"] % len(options)
        chosen = options[idx]["id"]
    return LlmVote(
        voter_id=spec.id,
        display_name=spec.display_name,
        council_seat=spec.council_seat,
        provider=spec.provider,
        model=spec.model,
        vote=vote,
        chosen_option_id=chosen,
        confidence=float(gospel.get("governance_delta", 0.5)),
        rationale=f"Gospel sim {gospel['consensus']['council_approvals']}/14 council approvals",
        latency_ms=2.0,
        live=False,
        error=None,
    )


def _query_voter(
    spec: VoterSpec,
    context: str,
    options: list[dict[str, Any]],
    proposal: str | None,
    timeout: int,
) -> LlmVote:
    started = time.time()
    user_prompt = _build_user_prompt(context, options, proposal)

    if spec.provider == "gospel_sim":
        return _call_gospel_sim(spec, context, options, proposal)

    try:
        if spec.provider == "anthropic":
            content = _call_anthropic(spec, user_prompt, timeout)
        elif spec.provider == "gemini":
            content = _call_gemini(spec, user_prompt, timeout)
        elif spec.provider == "openai":
            if not spec.base_url:
                raise ValueError("missing base_url for openai-compatible voter")
            content = _call_openai_compatible(spec, user_prompt, timeout)
        else:
            raise ValueError(f"unsupported provider: {spec.provider}")

        parsed = _parse_vote_json(content)
        latency = round((time.time() - started) * 1000, 2)
        return LlmVote(
            voter_id=spec.id,
            display_name=spec.display_name,
            council_seat=spec.council_seat,
            provider=spec.provider,
            model=spec.model,
            vote=parsed["vote"],
            chosen_option_id=parsed["chosen_option_id"],
            confidence=parsed["confidence"],
            rationale=parsed["rationale"],
            latency_ms=latency,
            live=True,
        )
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, KeyError, ValueError) as err:
        latency = round((time.time() - started) * 1000, 2)
        return LlmVote(
            voter_id=spec.id,
            display_name=spec.display_name,
            council_seat=spec.council_seat,
            provider=spec.provider,
            model=spec.model,
            vote="abstain",
            chosen_option_id=None,
            confidence=0.0,
            rationale="",
            latency_ms=latency,
            live=False,
            error=str(err),
        )


def _aggregate_votes(
    votes: list[LlmVote],
    options: list[dict[str, Any]],
) -> tuple[int, bool, str | None, str | None, dict[str, float]]:
    option_ids = {opt["id"] for opt in options}
    option_labels = {opt["id"]: opt.get("label", opt["id"]) for opt in options}
    scores: dict[str, float] = {oid: 0.0 for oid in option_ids}

    seat_ballots: dict[int, list[Vote]] = {}
    for vote in votes:
        seat_ballots.setdefault(vote.council_seat, []).append(vote.vote)
        if vote.vote == "approve" and vote.chosen_option_id in option_ids:
            weight = vote.confidence
            for raw in _load_voters_config().get("voters", []):
                if raw.get("id") == vote.voter_id:
                    weight *= float(raw.get("weight", 1.0))
                    break
            scores[vote.chosen_option_id] += weight

    council_approvals = 0
    for seat, ballots in seat_ballots.items():
        if ballots.count("approve") > ballots.count("reject"):
            council_approvals += 1
        elif ballots.count("approve") == ballots.count("reject") and seat == 1:
            council_approvals += 1

    threshold_met = council_approvals >= CONSENSUS_THRESHOLD[0]
    winning_id = None
    winning_label = None
    if scores:
        winning_id = max(scores, key=lambda k: scores[k])
        if scores[winning_id] > 0:
            winning_label = option_labels.get(winning_id)
        else:
            winning_id = None

    return council_approvals, threshold_met, winning_id, winning_label, scores


class LlmConsensusEngine:
    def __init__(self, max_workers: int | None = None) -> None:
        cfg = _load_voters_config()
        self.timeout = int(cfg.get("default_timeout_seconds", 45))
        self.max_workers = max_workers or int(os.getenv("LLM_CONSENSUS_WORKERS", "8"))

    def resolve_voters(self) -> list[VoterSpec]:
        voters: list[VoterSpec] = []
        for raw in _load_voters_config().get("voters", []):
            spec = _resolve_voter(raw)
            if spec:
                voters.append(spec)
        return voters

    def run_next_step(
        self,
        *,
        context: str,
        options: list[dict[str, Any]],
        proposal: str | None = None,
    ) -> LlmConsensusReport:
        if not options:
            raise ValueError("options must be a non-empty list of {id, label, detail?}")

        voters = self.resolve_voters()
        votes: list[LlmVote] = []

        with ThreadPoolExecutor(max_workers=min(self.max_workers, max(1, len(voters)))) as pool:
            futures = {
                pool.submit(_query_voter, spec, context, options, proposal, self.timeout): spec
                for spec in voters
            }
            for future in as_completed(futures):
                votes.append(future.result())

        live_count = sum(1 for v in votes if v.live)
        sim_count = len(votes) - live_count
        council_approvals, threshold_met, winning_id, winning_label, scores = _aggregate_votes(
            votes, options
        )

        sig_payload = f"{context}:{winning_id}:{council_approvals}:{threshold_met}"
        consensus_key = os.getenv("KIMICLAW_CONSENSUS_KEY", "kimiclaw-dev")
        signature = hashlib.sha256(f"{consensus_key}:{sig_payload}".encode()).hexdigest()[:32]

        return LlmConsensusReport(
            mode="next_step",
            context=context,
            options=options,
            votes=votes,
            live_voter_count=live_count,
            simulated_voter_count=sim_count,
            council_approvals=council_approvals,
            threshold_met=threshold_met,
            winning_option_id=winning_id,
            winning_option_label=winning_label,
            option_scores={k: round(v, 4) for k, v in scores.items()},
            kimiclaw_signature=signature,
        )


def run_llm_consensus(
    *,
    context: str,
    options: list[dict[str, Any]],
    proposal: str | None = None,
    output_path: str | Path | None = None,
) -> dict[str, Any]:
    engine = LlmConsensusEngine()
    report = engine.run_next_step(context=context, options=options, proposal=proposal)
    payload = report.to_dict()

    path = Path(output_path or os.getenv("LLM_CONSENSUS_OUTPUT", str(DEFAULT_OUTPUT)))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    payload["output_path"] = str(path)
    return payload
