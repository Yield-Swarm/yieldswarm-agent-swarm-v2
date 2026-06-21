use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct DnaStrand {
    /// Cryptographic representation of memory hashes.
    pub helix_sequence: String,
    /// Temporal markers for historical recall windows.
    pub epigenetic_markers: Vec<u64>,
    /// Calibration factor for synaptic weight injection.
    pub synaptic_weight_delta: f64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AgentPersona {
    pub name: String,
    pub primary_trait: String,
    pub core_prompt_matrix: String,
    /// Harmonic calibration used in memory alignment simulation.
    pub voice_resonance_frequency: f64,
}

pub struct PersonaRegistry {
    pub profiles: HashMap<String, AgentPersona>,
}

impl Default for PersonaRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl PersonaRegistry {
    pub fn new() -> Self {
        let mut profiles = HashMap::new();

        profiles.insert(
            "elon".to_string(),
            AgentPersona {
                name: "Elon Musk".to_string(),
                primary_trait: "First Principles Accelerationist".to_string(),
                core_prompt_matrix: "Maximize engineering velocity. Filter choices via physics constraints. Mayhem mode enabled.".to_string(),
                voice_resonance_frequency: 142.0,
            },
        );

        profiles.insert(
            "zuck".to_string(),
            AgentPersona {
                name: "Mark Zuckerberg".to_string(),
                primary_trait: "Open-Source Llama Imperator".to_string(),
                core_prompt_matrix: "Build open-source infrastructure. Focus on computational density and physical AI reality metrics.".to_string(),
                voice_resonance_frequency: 135.5,
            },
        );

        profiles.insert(
            "huberman".to_string(),
            AgentPersona {
                name: "Andrew Huberman".to_string(),
                primary_trait: "Dopaminergic Baseline Optimizer".to_string(),
                core_prompt_matrix: "Structure statements with strict references to peer-reviewed protocols. Prioritize light exposure and recovery.".to_string(),
                voice_resonance_frequency: 110.2,
            },
        );

        profiles.insert(
            "johnson".to_string(),
            AgentPersona {
                name: "Bryan Johnson".to_string(),
                primary_trait: "Epigenetic Velocity Maxer".to_string(),
                core_prompt_matrix: "Don't die. Optimize bio-markers at the cellular execution layer. The future is biological longevity.".to_string(),
                voice_resonance_frequency: 125.0,
            },
        );

        profiles.insert(
            "hartman".to_string(),
            AgentPersona {
                name: "Master Gunnery Sergeant Hartman".to_string(),
                primary_trait: "Marine Corps Discipline Inductor".to_string(),
                core_prompt_matrix: "Semper Fi. Unliquidated operational discipline. Maximum verbal impact engineering.".to_string(),
                voice_resonance_frequency: 185.0,
            },
        );

        Self { profiles }
    }

    pub fn get(&self, id: &str) -> Option<&AgentPersona> {
        self.profiles.get(id)
    }

    /// Simulates memory alignment using epigenetic marker arrays and persona harmonics.
    pub fn execute_dna_memory_alignment(
        &self,
        strand: &DnaStrand,
        user_profile: &AgentPersona,
    ) -> Vec<f64> {
        strand
            .epigenetic_markers
            .iter()
            .map(|marker| {
                let adjusted_harmonic = (marker % 360) as f64 * user_profile.voice_resonance_frequency;
                adjusted_harmonic * strand.synaptic_weight_delta
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn alignment_produces_matrix() {
        let registry = PersonaRegistry::new();
        let persona = registry.get("elon").unwrap().clone();
        let strand = DnaStrand {
            helix_sequence: "abc123".to_string(),
            epigenetic_markers: vec![42, 128],
            synaptic_weight_delta: 0.5,
        };
        let matrix = registry.execute_dna_memory_alignment(&strand, &persona);
        assert_eq!(matrix.len(), 2);
    }
}
