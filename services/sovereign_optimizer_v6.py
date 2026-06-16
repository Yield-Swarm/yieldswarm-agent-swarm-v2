"""
Sovereign Optimizer v6 — multi-objective routing, Q-learning, wormholes, NFT tier bonus.
Used by cloud_scheduler and odysseus-router for GPU placement decisions.
"""

from __future__ import annotations

import random
from collections import Counter, defaultdict
from typing import Dict, List, Optional


class SovereignOptimizerV6:
    def __init__(self) -> None:
        self.nodes: Dict[str, dict] = {}
        self.agent_nfts: Dict[str, dict] = {}
        self.wormholes: Dict[str, List[str]] = {}
        self.q_table: Dict[str, Dict[str, float]] = defaultdict(lambda: defaultdict(float))
        self.performance_history: Dict[str, list] = defaultdict(list)
        self.learning_rate = 0.12
        self.exploration_rate = 0.15

    def update_node(self, node_id: str, metrics: dict) -> None:
        self.nodes[node_id] = metrics

    def update_agent_nft(self, agent_id: str, mutation_data: dict) -> None:
        self.agent_nfts[agent_id] = mutation_data

    def create_wormholes(self) -> None:
        node_ids = list(self.nodes.keys())
        self.wormholes = {}
        for node in node_ids:
            others = [n for n in node_ids if n != node]
            if not others:
                continue
            k = random.randint(1, min(3, len(others)))
            self.wormholes[node] = random.sample(others, k=k)

    def calculate_multi_objective_score(self, node_id: str, task_type: str) -> float:
        data = self.nodes.get(node_id, {})
        speed = data.get("tokens_per_second", 60) / 180
        cost = 1 / max(data.get("cost_per_hour", 0.6), 0.1)
        reliability = data.get("success_rate", 0.88)
        load_factor = 1 - data.get("current_utilization", 0.5)
        energy = 1 - data.get("energy_impact", 0.35)

        weights = {
            "embedding": [0.40, 0.25, 0.10, 0.15, 0.10],
            "heavy_reasoning": [0.20, 0.15, 0.30, 0.15, 0.20],
            "telemetry": [0.35, 0.30, 0.15, 0.10, 0.10],
        }.get(task_type, [0.25, 0.20, 0.20, 0.15, 0.20])

        return (
            speed * weights[0]
            + cost * weights[1]
            + reliability * weights[2]
            + load_factor * weights[3]
            + energy * weights[4]
        )

    def calculate_score_with_nft(self, node_id: str, agent_id: Optional[str], task_type: str) -> float:
        base = self.calculate_multi_objective_score(node_id, task_type)
        if not agent_id:
            return base
        nft = self.agent_nfts.get(agent_id, {})
        tier_bonus = nft.get("mutation_tier", 1) * 0.08
        consistency = nft.get("consistency_score", 0.5) * 0.12
        return base + tier_bonus + consistency

    def run_monte_carlo(self, task_type: str, iterations: int = 5000) -> str:
        scores: Dict[str, float] = {nid: 0.0 for nid in self.nodes}
        for _ in range(iterations):
            for node_id, data in self.nodes.items():
                base = data.get("tokens_per_second", 50)
                variance = random.gauss(0, base * 0.15)
                cost_penalty = data.get("cost_per_hour", 0.5) * 0.8
                scores[node_id] += base + variance - cost_penalty
        return max(scores, key=scores.get)

    def optimize(self, task_type: str, priority: str = "normal", agent_id: Optional[str] = None) -> Optional[str]:
        if not self.nodes:
            return None

        if random.random() < 0.07:
            self.create_wormholes()

        if priority in ("high", "critical"):
            chosen = self.run_monte_carlo(task_type, iterations=5000)
        elif random.random() < self.exploration_rate:
            chosen = random.choice(list(self.nodes.keys()))
        else:
            scores = {
                nid: self.calculate_score_with_nft(nid, agent_id, task_type) + self.q_table[task_type][nid] * 0.3
                for nid in self.nodes
            }
            for nid in list(scores.keys()):
                for target in self.wormholes.get(nid, []):
                    if target in scores:
                        scores[nid] += scores[target] * 0.1
            chosen = max(scores, key=scores.get)

        reward = 1.0 if priority == "high" else 0.7
        self.q_table[task_type][chosen] += self.learning_rate * reward
        return chosen
