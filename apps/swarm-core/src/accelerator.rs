use crate::config::EnvironmentConfig;
use serde_json::json;
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio::time::{sleep, Duration};

pub struct ParticleAccelerator {
    pub config: EnvironmentConfig,
}

impl ParticleAccelerator {
    pub fn new() -> Self {
        Self {
            config: EnvironmentConfig::from_env(),
        }
    }

    pub fn with_config(config: EnvironmentConfig) -> Self {
        Self { config }
    }

    /// Mandelbrot escape-time heuristic → non-linear backoff delay per layer/elevator.
    pub fn calculate_mandelbrot_delay(&self, layer: u8, elevator_id: usize) -> Duration {
        let cr = (layer as f64 * 0.12) - 1.5;
        let ci = (elevator_id as f64 * 0.18) - 1.0;

        let (mut zr, mut zi) = (0.0, 0.0);
        let mut iterations = 0;
        let max_iterations = 32;

        while zr * zr + zi * zi <= 4.0 && iterations < max_iterations {
            let temp = zr * zr - zi * zi + cr;
            zi = 2.0 * zr * zi + ci;
            zr = temp;
            iterations += 1;
        }

        Duration::from_millis((iterations * 20) as u64)
    }

    /// 14 parallel elevators × 14 processing layers; emits shard collision frames.
    pub async fn run_synchrotron_loop(&self) {
        for warning in self.config.validate_production() {
            log::warn!("[Accelerator] config: {}", warning);
        }

        let (tx, mut rx) = mpsc::channel(1000);
        log::info!(
            "[Accelerator] Launching {} elevators across {} cron shards ({} total agents)",
            14,
            self.config.cron_shard_count,
            self.config.agent_count_total
        );

        for elevator_id in 1..=14 {
            let tx_clone = tx.clone();
            let agents_per_shard = self.config.agents_per_shard;
            let cron_shard_count = self.config.cron_shard_count;
            let accel = Arc::new(ParticleAccelerator {
                config: self.config.clone(),
            });

            tokio::spawn(async move {
                for layer in 1..=14u8 {
                    let delay = accel
                        .calculate_mandelbrot_delay(layer, elevator_id)
                        .max(Duration::from_millis((layer as u64) * (elevator_id as u64)));
                    sleep(delay).await;

                    let _ = tx_clone
                        .send(json!({
                            "elevator": elevator_id,
                            "layer_fired": layer,
                            "allocated_agents": agents_per_shard,
                            "cron_shards": cron_shard_count,
                            "status": "ACCELERATED"
                        }))
                        .await;
                }
            });
        }
        drop(tx);

        while let Some(msg) = rx.recv().await {
            log::debug!("Synchrotron frame: {:?}", msg);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mandelbrot_delay_bounded() {
        let accel = ParticleAccelerator::new();
        let d = accel.calculate_mandelbrot_delay(7, 3);
        assert!(d.as_millis() <= 32 * 20);
    }
}
