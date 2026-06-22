"""Tests for mining path normalization."""

from pathlib import Path

from mining.paths import collapse_literal_tilde, resolve_run_dir


def test_collapse_literal_tilde_segment(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    home = Path.home()
    bad = home / "yieldswarm-agent-swarm-v2" / "~" / "yieldswarm-agent-swarm-v2" / ".run" / "mining"
    fixed = collapse_literal_tilde(bad)
    assert "~" not in fixed.parts
    assert fixed == home / "yieldswarm-agent-swarm-v2" / ".run" / "mining"


def test_resolve_run_dir_relative(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    out = resolve_run_dir(".run/mining", repo)
    assert out == (repo / ".run" / "mining").resolve()
