//! CERN-inspired proton synchrotron — 14 elevators × 14 layers × Mandelbrot scheduler.
//!
//! Solenoid 1: Ingestion & Runtime (L1–3)
//! Solenoid 2: Interface & Cloud (L3–9)
//! Solenoid 3: DeFi & Compute (L10–14)
//! 14-Elevator Synchrotron: parallel particle streams through fractal spacetime.

use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::time::sleep;
use yieldswarm_core::accelerator::{MandelbrotAccelerator, ParticleFrame};

const ELEVATOR_COUNT: usize = 14;
const LAYER_COUNT: u8 = 14;
const CHANNEL_CAPACITY: usize = 1000;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env()
                .add_directive("swarm_core=info".parse().unwrap()),
        )
        .init();

    let accelerator = Arc::new(MandelbrotAccelerator::new());
    let (particle_tx, mut particle_rx) = mpsc::channel::<ParticleFrame>(CHANNEL_CAPACITY);

    tracing::info!("CERN-Inspired Proton Synchrotron Framework booted");
    tracing::info!("Tree of Life harmonic grid: online");

    let mut handles = Vec::with_capacity(ELEVATOR_COUNT);

    for elevator_id in 1..=ELEVATOR_COUNT {
        let acc = Arc::clone(&accelerator);
        let tx = particle_tx.clone();

        handles.push(tokio::spawn(async move {
            for layer in 1..=LAYER_COUNT {
                let phase = MandelbrotAccelerator::phase_for_layer(layer);
                let resonance_delay = acc.calculate_fractal_backoff(layer, elevator_id);
                sleep(resonance_delay).await;

                let frame = ParticleFrame::new(
                    layer,
                    elevator_id,
                    format!("Data packet accelerated via Elevator {elevator_id}"),
                    resonance_delay.as_millis() as u64,
                );

                tracing::info!(
                    elevator = elevator_id,
                    layer = layer,
                    phase = %phase.label(),
                    delay_ms = resonance_delay.as_millis(),
                    "elevator fired"
                );

                if tx.send(frame).await.is_err() {
                    break;
                }
            }
        }));
    }

    // Drop primary sender; channel closes when all elevator tasks finish.
    drop(particle_tx);

    let mut total_processed_events = 0usize;
    while let Some(frame) = particle_rx.recv().await {
        total_processed_events += 1;
        tracing::debug!(
            layer = frame.layer_id,
            elevator = frame.elevator_id,
            energy = frame.energy_coefficient,
            "particle collision"
        );
    }

    for handle in handles {
        let _ = handle.await;
    }

    tracing::info!(
        total = total_processed_events,
        expected = ELEVATOR_COUNT * LAYER_COUNT as usize,
        "mass collision loop complete"
    );

    println!(
        "==> Mass collision loop complete. Total Accelerated Swarm Events: {total_processed_events}"
    );
}
