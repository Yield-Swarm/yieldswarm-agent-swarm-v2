//! Multi-LLM routing connectors for YieldSwarm Phase 3.
//!
//! Bridges the Rust connector layer with the TypeScript stack via `src/lib/llm/connectors/`.

pub mod connectors;

pub use connectors::{GeminiConnector, KimiClawConnector, SuperGrokConnector};
