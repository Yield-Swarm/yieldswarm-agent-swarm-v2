# Particle Accelerator Engine

CERN-inspired proton synchrotron: **3 solenoid rings** + **14-elevator Mandelbrot scheduler**.

```
                [ THE TREE OF LIFE HARMONIC MATRIX ]
                                 │
     ┌───────────────────────────┴───────────────────────────┐
     ▼                                                       ▼
 ╔═════════════════════════════════════════════════════════════════════╗
 ║                     SOLENOID 1: INGESTION & RUNTIME                 ║
 ║  Layer 1 (Core)  │  Layer 2 (Solenoids)  │  Layer 3 (A-C: APIs)    ║
 ╚═════════════════════════════════════════════════════════════════════╝
     │
     ▼
 ╔═════════════════════════════════════════════════════════════════════╗
 ║                     SOLENOID 2: INTERFACE & CLOUD                   ║
 ║  Layers 4-5 (Registry/Eliza)  │  Layers 6-7 (Router)  │  Layers 8-9 ║
 ╚═════════════════════════════════════════════════════════════════════╝
     │
     ▼
 ╔═════════════════════════════════════════════════════════════════════╗
 ║                     SOLENOID 3: DEFI & COMPUTE REGIME               ║
 ║  Layers 10-11 (Grok/Gemini)   │  Layer 12-13  │  Layer 14 (Infra)   ║
 ╚═════════════════════════════════════════════════════════════════════╝
     │
     ▼
 ╔═════════════════════════════════════════════════════════════════════╗
 ║           14-ELEVATOR SYNCHROTRON (MANDELBROT SCHEDULER)            ║
 ║  Fires all 14 layers simultaneously via Complex Fractal Frequency   ║
 ╚═════════════════════════════════════════════════════════════════════╝
```

## Run

```bash
cargo run -p swarm-core
# or
make swarm-accelerator
```

## Modules

| Path | Role |
|------|------|
| `apps/swarm-core/src/main.rs` | 14-elevator parallel particle streams |
| `crates/yieldswarm-core/src/accelerator/` | MandelbrotAccelerator + SolenoidRing |
| `crates/yieldswarm-core/src/orchestrator/` | Apollo Nexus + registry integration |

## Mandelbrot backoff

`Z_{n+1} = Z_n² + C` where `C = (layer×0.15 - 2, elevator×0.25 - 1.25)`. Escape iterations × 15ms = resonance delay per frame.
