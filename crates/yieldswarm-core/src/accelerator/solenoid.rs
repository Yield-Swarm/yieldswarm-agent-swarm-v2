//! Three solenoid rings mapping the 14-layer stack.

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SolenoidRing {
    /// Layers 1–3 — ingestion & runtime (variants A/B/C on layer 3).
    Solenoid1 {
        layers: Vec<u8>,
        variants: Vec<char>,
    },
    /// Layers 3–9 — interface & cloud (layer 3 is transmutation interface).
    Solenoid2 { layers: Vec<u8> },
    /// Layers 10–14 — DeFi & compute regime.
    Solenoid3 { layers: Vec<u8> },
}

impl SolenoidRing {
    pub fn ingestion_runtime() -> Self {
        Self::Solenoid1 {
            layers: vec![1, 2, 3],
            variants: vec!['A', 'B', 'C'],
        }
    }

    pub fn interface_cloud() -> Self {
        Self::Solenoid2 {
            layers: (3..=9).collect(),
        }
    }

    pub fn defi_compute() -> Self {
        Self::Solenoid3 {
            layers: (10..=14).collect(),
        }
    }
}

/// Named phase for a layer inside the accelerator pipeline.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum SolenoidPhase {
    Solenoid1Core,
    Solenoid1Transmutation,
    Solenoid2ApiGrid,
    Solenoid3DefiIngestion,
}

impl SolenoidPhase {
    pub fn from_layer(layer: u8) -> Self {
        match layer {
            1..=2 => Self::Solenoid1Core,
            3 => Self::Solenoid1Transmutation,
            4..=9 => Self::Solenoid2ApiGrid,
            _ => Self::Solenoid3DefiIngestion,
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Solenoid1Core => "Solenoid 1 (Core Matrix)",
            Self::Solenoid1Transmutation => "Solenoid 1-2 Transmutation Interface (L3 A-C)",
            Self::Solenoid2ApiGrid => "Solenoid 2 (Dynamic API Grid)",
            Self::Solenoid3DefiIngestion => "Solenoid 3 (High-Value DeFi Ingestion Node)",
        }
    }
}

/// A single particle frame accelerated through one layer on one elevator.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParticleFrame {
    pub layer_id: u8,
    pub elevator_id: usize,
    pub payload: String,
    pub energy_coefficient: f64,
    pub solenoid_phase: SolenoidPhase,
    pub resonance_delay_ms: u64,
}

impl ParticleFrame {
    pub const GOLDEN_RATIO: f64 = 1.618_033_988_75;

    pub fn new(layer_id: u8, elevator_id: usize, payload: impl Into<String>, delay_ms: u64) -> Self {
        Self {
            layer_id,
            elevator_id,
            payload: payload.into(),
            energy_coefficient: Self::GOLDEN_RATIO,
            solenoid_phase: SolenoidPhase::from_layer(layer_id),
            resonance_delay_ms: delay_ms,
        }
    }
}
