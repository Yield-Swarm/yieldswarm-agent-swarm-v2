# AgentSwarm fallback worker container.
#
# Run directly by RunPod pods and via Docker (systemd unit) on the Azure/GCP/
# Vultr VM images. Build & push:
#
#   docker build -t ghcr.io/yieldswarm/agentswarm-worker:latest infra/packer/docker
#   docker push ghcr.io/yieldswarm/agentswarm-worker:latest
#
# For GPU workers, swap the base image for an NVIDIA CUDA runtime, e.g.
#   nvidia/cuda:12.4.1-runtime-ubuntu22.04
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    AGENTS_PER_SHARD=84 \
    WORKER_FALLBACK_MODE=true

WORKDIR /app

COPY worker_entrypoint.py /app/worker_entrypoint.py

# Lightweight healthcheck: the worker writes a heartbeat file each loop.
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD test -f /tmp/agentswarm-worker.heartbeat && \
      find /tmp/agentswarm-worker.heartbeat -mmin -2 | grep -q . || exit 1

ENTRYPOINT ["python", "/app/worker_entrypoint.py"]
