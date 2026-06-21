"""Tests for Single Pane prompt registry and YSLR queue."""

from services.single_pane.registry import PromptRegistry, get_prompt_status
from services.yslr.queue import YslrQueue
from services.utc.scheduler import UniversalTimeCoordinate
from services.astro_schedule.engine import AstrologicalScheduleEngine
from services.business.profit_share import allocate_revenue


def test_prompt_registry_has_20_prompts():
    summary = get_prompt_status()
    assert summary["total"] == 20
    assert summary["ready"] + summary["partial"] + summary["missing"] == 20


def test_yslr_enqueue_dequeue():
    q = YslrQueue()
    task = q.enqueue("elevator-7", {"action": "ping"})
    assert task.id
    result = q.dequeue("elevator-7")
    assert result is not None
    _, payload = result
    assert payload["action"] == "ping"


def test_utc_coordinate_monotonic():
    utc = UniversalTimeCoordinate(pulse_interval_sec=60)
    a = utc.now()
    b = utc.now()
    assert a.coordinate <= b.coordinate


def test_aquarius_engine_returns_multiplier():
    engine = AstrologicalScheduleEngine()
    window = engine.evaluate()
    assert window.multiplier_bps in (100, 150)


def test_jack_profit_share_3_percent():
    result = allocate_revenue(1000.0)
    jack = next(a for a in result["allocations"] if a["id"] == "jack")
    assert jack["bps"] == 300
    assert jack["amount_usd"] == 30.0
