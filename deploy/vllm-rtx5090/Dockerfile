# vLLM RTX 5090 — continuous batching + OpenAI-compatible API
# Build: docker build -t ghcr.io/yield-swarm/vllm-rtx5090:latest deploy/vllm-rtx5090
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev git wget ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --upgrade pip \
    && pip3 install --no-cache-dir "vllm==0.6.0"

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000 9090

ENTRYPOINT ["/app/entrypoint.sh"]
