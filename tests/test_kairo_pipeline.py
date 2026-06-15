import unittest

from kairo.identity.wallet import create_driver_identity, identity_from_private_key
from kairo.pipeline.mandelbrot import evaluate_mandelbrot, route_to_tree, TREE_OF_LIFE_NODES


class KairoIdentityTests(unittest.TestCase):
    def test_identity_is_deterministic_from_seed(self):
        seed = b"test-seed-32-bytes-long-enough!!"
        id_a, key_a = create_driver_identity(seed=seed)
        id_b, key_b = create_driver_identity(seed=seed)
        self.assertEqual(id_a.evm_address, id_b.evm_address)
        self.assertEqual(key_a, key_b)
        self.assertTrue(id_a.iotex_address.startswith("io1"))

    def test_identity_from_private_key(self):
        _, private_key = create_driver_identity()
        identity = identity_from_private_key(private_key)
        self.assertTrue(identity.evm_address.startswith("0x"))


class MandelbrotPipelineTests(unittest.TestCase):
    def test_evaluate_returns_tree_node(self):
        payload = {"speed_mps": 12.5, "odometer_m": 1200}
        score = evaluate_mandelbrot("driver-1", payload)
        self.assertIn(score.tree_node, TREE_OF_LIFE_NODES)
        self.assertGreater(score.reward_weight, 0)

    def test_route_batch(self):
        signed = [
            {
                "payload": {
                    "driver_id": "d1",
                    "evm_address": "0x" + "ab" * 20,
                    "timestamp_ms": 1,
                    "latitude": 1.0,
                    "longitude": 2.0,
                    "speed_mps": 5.0,
                    "heading_deg": 90.0,
                },
                "signature": "0x" + "cd" * 32,
            }
        ]
        routed = route_to_tree("d1", signed)
        self.assertEqual(len(routed), 1)
        self.assertIn("collection", routed[0])


if __name__ == "__main__":
    unittest.main()
