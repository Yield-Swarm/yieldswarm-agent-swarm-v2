"""APN AgentSwarm runtime package.

The historical agent files (`akash-optimizer.py` and friends) use hyphens,
which Python's import system rejects. This package re-exports them under
import-safe names so the Akash entrypoint can invoke them with
`python -m agents.<name>`.
"""
