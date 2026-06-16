#!/bin/bash
# deploy/entrypoint.monitor.sh
set -euo pipefail

VRAM_MAX_BYTES=31677329408
TEMP_THRESHOLD_CELSIUS=83
POLL_INTERVAL_SECONDS=2

echo "=== INITIALIZING QUADRILATERAL AXIS HARDWARE RESOURCE GUARDIAN ==="

while true; do
    if metrics=$(curl -s http://127.0.0.1:8000/metrics 2>/dev/null); then
        gpu_temp=$(echo "$metrics" | grep "gpu_temperature_celsius" | awk '{print $2}' || echo 0)
        vram_used=$(echo "$metrics" | grep "vram_allocated_bytes" | awk '{print $2}' || echo 0)

        if (( $(echo "$gpu_temp > $TEMP_THRESHOLD_CELSIUS" | bc -l) )); then
            echo "[X-AXIS WARN] Hardware thermal overload detected at ${gpu_temp}°C. Throttling pipeline load..."
            curl -s -X POST http://127.0.0.1:8080/api/solenoid/throttle \
                -H "Content-Type: application/json" \
                -d "{\"status\":\"THERMAL_LIMIT_EXCEEDED\",\"temp\":\"$gpu_temp\"}" || true
        fi

        if (( $(echo "$vram_used > $VRAM_MAX_BYTES" | bc -l) )); then
            echo "[X-AXIS CRIT] VRAM saturation breached limit. Forcing cache prune pass..."
            curl -s -X POST http://127.0.0.1:8080/api/context/prune \
                -H "Content-Type: application/json" \
                -d '{"force":true}' || true
        fi
    fi
    sleep "$POLL_INTERVAL_SECONDS"
done
