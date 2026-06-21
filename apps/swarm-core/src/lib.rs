//! YieldSwarm swarm-core — persona profiles and shard accelerator loops.

pub mod accelerator;
pub mod config;
pub mod dna_persona;

pub use accelerator::ParticleAccelerator;
pub use config::EnvironmentConfig;
pub use dna_persona::{AgentPersona, DnaStrand, PersonaRegistry};
