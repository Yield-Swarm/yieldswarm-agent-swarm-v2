# Akash Optimizer Agent
# Connects to current allocations (GPU miners, OpenClaw, Eliza, Gensyn)
# Optimizes with $200 credits, extends leases, migrates providers
# Part of MEGA TASK scaling (Hydrogen Particle VM sharding)
#
# The production implementation of lease supervision / auto-failover now lives in
# ../akash/. This agent delegates to the lease-manager so the swarm and the
# standalone manager share one code path.
#
#   akash/akash-deploy.sh   -> Akash CLI wrapper (deploy / select RTX 3090 / lease)
#   akash/lease-manager.py  -> 60s health-check loop + auto-failover + telemetry
#
# Run as a one-shot pass (cron) or a daemon:
#   python3 akash/lease-manager.py --once
#   ./akash/run.sh start

import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEASE_MANAGER = os.path.join(REPO_ROOT, 'akash', 'lease-manager.py')


def run_once() -> int:
    """Trigger a single reconcile pass of the production lease manager."""
    if not os.path.isfile(LEASE_MANAGER):
        print('Akash lease-manager not found at', LEASE_MANAGER)
        return 1
    return subprocess.call([sys.executable, LEASE_MANAGER, '--once'])


if __name__ == '__main__':
    print('Akash Optimizer Agent active - delegating to akash/lease-manager.py')
    raise SystemExit(run_once())