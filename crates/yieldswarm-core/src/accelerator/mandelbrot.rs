//! Mandelbrot escape-time scheduler for fractal backoff across 14 elevators.

use super::solenoid::{SolenoidRing, SolenoidPhase};
use std::time::Duration;

/// Tree-of-Life harmonic matrix — three solenoid rings + fractal scheduler.
pub struct MandelbrotAccelerator {
    pub solenoid_1: SolenoidRing,
    pub solenoid_2: SolenoidRing,
    pub solenoid_3: SolenoidRing,
}

impl Default for MandelbrotAccelerator {
    fn default() -> Self {
        Self::new()
    }
}

impl MandelbrotAccelerator {
    pub fn new() -> Self {
        Self {
            solenoid_1: SolenoidRing::ingestion_runtime(),
            solenoid_2: SolenoidRing::interface_cloud(),
            solenoid_3: SolenoidRing::defi_compute(),
        }
    }

    pub fn phase_for_layer(layer: u8) -> SolenoidPhase {
        SolenoidPhase::from_layer(layer)
    }

    /// Mandelbrot escape-time matrix: Z_{n+1} = Z_n² + C
    /// Returns deterministic delay from fractal escape velocity.
    pub fn calculate_fractal_backoff(&self, layer: u8, elevator_id: usize) -> Duration {
        let cr = (layer as f64 * 0.15) - 2.0;
        let ci = (elevator_id as f64 * 0.25) - 1.25;

        let (mut zr, mut zi) = (0.0, 0.0);
        let mut iterations = 0u32;
        let max_iterations = 32;

        while zr * zr + zi * zi <= 4.0 && iterations < max_iterations {
            let temp = zr * zr - zi * zi + cr;
            zi = 2.0 * zr * zi + ci;
            zr = temp;
            iterations += 1;
        }

        Duration::from_millis(iterations as u64 * 15)
    }

    /// Escape iterations (for telemetry / Mandelbrot scoring).
    pub fn escape_iterations(layer: u8, elevator_id: usize) -> u32 {
        let cr = (layer as f64 * 0.15) - 2.0;
        let ci = (elevator_id as f64 * 0.25) - 1.25;
        let (mut zr, mut zi) = (0.0, 0.0);
        let mut iterations = 0u32;
        while zr * zr + zi * zi <= 4.0 && iterations < 32 {
            let temp = zr * zr - zi * zi + cr;
            zi = 2.0 * zr * zi + ci;
            zr = temp;
            iterations += 1;
        }
        iterations
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backoff_is_deterministic() {
        let acc = MandelbrotAccelerator::new();
        let a = acc.calculate_fractal_backoff(7, 3);
        let b = acc.calculate_fractal_backoff(7, 3);
        assert_eq!(a, b);
    }

    #[test]
    fn three_solenoid_rings_configured() {
        let acc = MandelbrotAccelerator::new();
        match &acc.solenoid_1 {
            SolenoidRing::Solenoid1 { layers, variants } => {
                assert_eq!(*layers, vec![1, 2, 3]);
                assert_eq!(*variants, vec!['A', 'B', 'C']);
            }
            _ => panic!("expected solenoid 1"),
        }
    }
}
