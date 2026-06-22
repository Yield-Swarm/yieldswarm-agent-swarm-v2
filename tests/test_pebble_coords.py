"""Tests for Pebble NMEA coordinate normalization."""

import unittest

from services.iot_hub.pebble_coords import nmea_to_decimal_degrees, normalize_pebble_packet


class TestPebbleCoords(unittest.TestCase):
    def test_nmea_latitude(self):
        # 3050.69225 → 30 + 50.69225/60
        self.assertAlmostEqual(nmea_to_decimal_degrees(3050.69225), 30.844871, places=5)

    def test_nmea_longitude(self):
        self.assertAlmostEqual(nmea_to_decimal_degrees(11448.65815), 114.810969, places=5)

    def test_normalize_packet(self):
        out = normalize_pebble_packet(
            {"snr": 14.2, "vbat": 3700, "latitude": 3050.69225, "longitude": 11448.65815, "timestamp": "t"},
            device_identity="io_nexus_pebble_01",
            edge_source="192.168.1.158",
        )
        self.assertEqual(out["network_edge_source"], "192.168.1.158")
        self.assertAlmostEqual(out["telemetry"]["latitude_dd"], 30.844871, places=5)


if __name__ == "__main__":
    unittest.main()
