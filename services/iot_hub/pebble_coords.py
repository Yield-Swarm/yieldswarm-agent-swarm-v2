"""Pebble / NMEA coordinate normalization — DDD°MM.MMM' → decimal degrees."""

from __future__ import annotations


def nmea_to_decimal_degrees(coord: float) -> float:
    """
    Convert NMEA-style DDDMM.MMMMM to decimal degrees.

    Example: 3050.69225 → 30 + 50.69225/60 = 30.845871
    """
    raw = float(coord)
    degrees = int(raw // 100)
    minutes = raw - (degrees * 100)
    return degrees + (minutes / 60.0)


def normalize_pebble_packet(
    packet: dict,
    *,
    device_identity: str,
    edge_source: str = "192.168.1.158",
) -> dict:
    lat = packet.get("latitude")
    lon = packet.get("longitude")
    lat_dd = nmea_to_decimal_degrees(lat) if lat is not None else None
    lon_dd = nmea_to_decimal_degrees(lon) if lon is not None else None

    return {
        "device_identity": device_identity,
        "network_edge_source": edge_source,
        "telemetry": {
            "snr": packet.get("snr"),
            "vbat": packet.get("vbat"),
            "latitude_dd": round(lat_dd, 6) if lat_dd is not None else None,
            "longitude_dd": round(lon_dd, 6) if lon_dd is not None else None,
            "timestamp": packet.get("timestamp"),
        },
    }
