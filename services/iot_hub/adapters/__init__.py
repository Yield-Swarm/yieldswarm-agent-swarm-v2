"""Device-type health check adapters."""

from .base import CheckResult, DeviceAdapter
from .registry import get_adapter

__all__ = ["CheckResult", "DeviceAdapter", "get_adapter"]