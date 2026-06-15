import unittest

from services.yieldswarm_model_router import (
    ModelLoad,
    WorkerState,
    YieldSwarmModelRouter,
    default_model_catalog,
)


def build_router() -> YieldSwarmModelRouter:
    return YieldSwarmModelRouter(
        workers=[
            WorkerState(
                worker_id="akash-rtx3090-a",
                provider_uri="http://worker-a.local:8000",
                great_delta_signal=0.5,
            ),
            WorkerState(
                worker_id="akash-rtx3090-b",
                provider_uri="http://worker-b.local:8000",
                queue_depth=5,
                great_delta_signal=0.1,
            ),
        ],
        models=default_model_catalog(),
    )


class YieldSwarmModelRouterTests(unittest.TestCase):
    def test_recommend_returns_task_compatible_route_with_vram_headroom(self) -> None:
        router = build_router()

        decision = router.recommend(
            task="coding",
            agent_id="deity-agent-17",
            priority=0.8,
            mutation_score=0.7,
        )

        self.assertIn(
            decision.model_id,
            {
                "llama-3.1-8b-instruct-q5",
                "qwen2.5-coder-7b-q5",
                "deepseek-r1-distill-llama-8b-q5",
            },
        )
        self.assertEqual(decision.worker_id, "akash-rtx3090-a")
        self.assertIn(decision.action, {"load", "serve"})

    def test_route_request_autoloads_selected_model(self) -> None:
        router = build_router()

        decision = router.route_request(task="agent", autoload=True)
        worker = router.workers[decision.worker_id]

        self.assertIn(decision.model_id, worker.loaded_models)
        self.assertEqual(worker.active_requests, 1)
        self.assertEqual(worker.loaded_models[decision.model_id].active_requests, 1)

        router.complete_request(worker_id=decision.worker_id, model_id=decision.model_id)
        self.assertEqual(worker.active_requests, 0)
        self.assertEqual(worker.loaded_models[decision.model_id].active_requests, 0)

    def test_load_model_evicts_idle_models_when_vram_is_tight(self) -> None:
        router = YieldSwarmModelRouter(
            workers=[
                WorkerState(
                    worker_id="akash-rtx3090-tight",
                    provider_uri="http://tight.local:8000",
                    loaded_models={
                        "llama-3.1-8b-instruct-q5": ModelLoad(
                            "llama-3.1-8b-instruct-q5", 8.0
                        ),
                        "qwen2.5-coder-7b-q5": ModelLoad(
                            "qwen2.5-coder-7b-q5", 8.5
                        ),
                    },
                )
            ],
            models=default_model_catalog(),
        )

        decision = router.load_model(
            model_id="mixtral-8x7b-instruct-q4",
            worker_id="akash-rtx3090-tight",
        )
        worker = router.workers["akash-rtx3090-tight"]

        self.assertEqual(decision.action, "loaded")
        self.assertTrue(decision.unload_before_load)
        self.assertIn("mixtral-8x7b-instruct-q4", worker.loaded_models)
        self.assertGreaterEqual(worker.free_vram_gb, 0.8)

    def test_rebalance_preloads_hot_task(self) -> None:
        router = build_router()

        result = router.rebalance({"task_weights": {"reasoning": 1.0}})

        self.assertTrue(result["actions"])
        loaded_model_ids = {
            load["model_id"]
            for worker in result["workers"]
            for load in worker["loaded_models"]
        }
        self.assertTrue(
            {
                "deepseek-r1-distill-llama-8b-q5",
                "mixtral-8x7b-instruct-q4",
            }
            & loaded_model_ids
        )


if __name__ == "__main__":
    unittest.main()
