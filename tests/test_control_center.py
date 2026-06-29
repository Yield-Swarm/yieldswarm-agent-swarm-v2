"""Control center FastAPI daemon tests."""

from __future__ import annotations

import unittest

from services.control_center.encrypted_id import mint_pow_id, mint_powui_id
from services.control_center.models import DeviceStatsIn


class ControlCenterModelsTest(unittest.TestCase):
    def test_device_stats_validation(self) -> None:
        d = DeviceStatsIn(device_id="phone-01", cpu_percent=50, memory_percent=40)
        self.assertEqual(d.device_id, "phone-01")

    def test_encrypted_ids(self) -> None:
        p = mint_pow_id("asic-1")
        u = mint_powui_id("ui-1")
        self.assertTrue(p.startswith("ys_pow_"))
        self.assertTrue(u.startswith("ys_powui_"))


if __name__ == "__main__":
    unittest.main()
