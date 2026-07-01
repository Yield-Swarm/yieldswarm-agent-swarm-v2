/**
 * Groth16 prover/verifier for ZKML Arena reputation scores.
 */

const fs = require("node:fs");
const path = require("node:path");
const { DEFAULT_WEIGHTS } = require("./reputation-scorer");

const DEFAULT_ARTIFACT_DIR = path.join(__dirname, "../../circuits/build");

function resolveArtifact(fileName, artifactDir = DEFAULT_ARTIFACT_DIR) {
  const full = path.join(artifactDir, fileName);
  if (!fs.existsSync(full)) {
    return null;
  }
  return full;
}

function artifactsAvailable(artifactDir = DEFAULT_ARTIFACT_DIR) {
  return Boolean(
    resolveArtifact("reputation_score_js/reputation_score.wasm", artifactDir) &&
      resolveArtifact("reputation_score_final.zkey", artifactDir)
  );
}

/**
 * @param {{ winRate: number, consistency: number, peerReview: number, stakeWeight: number, weights?: number[], score: number }} input
 */
function buildCircuitInput(input) {
  const weights = input.weights ?? DEFAULT_WEIGHTS;
  return {
    winRate: input.winRate,
    consistency: input.consistency,
    peerReview: input.peerReview,
    stakeWeight: input.stakeWeight,
    weights,
    score: input.score,
  };
}

async function proveReputation(input, options = {}) {
  const artifactDir = options.artifactDir ?? DEFAULT_ARTIFACT_DIR;
  const wasmPath = resolveArtifact("reputation_score_js/reputation_score.wasm", artifactDir);
  const zkeyPath = resolveArtifact("reputation_score_final.zkey", artifactDir);

  if (!wasmPath || !zkeyPath) {
    return {
      mockProof: true,
      proof: { pi_a: [], pi_b: [], pi_c: [], protocol: "groth16-mock" },
      publicSignals: [...(input.weights ?? DEFAULT_WEIGHTS).map(String), String(input.score)],
    };
  }

  const snarkjs = await import("snarkjs");
  const circuitInput = buildCircuitInput(input);
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    circuitInput,
    wasmPath,
    zkeyPath
  );
  return { mockProof: false, proof, publicSignals };
}

async function verifyReputationProof(proofBundle, options = {}) {
  if (proofBundle.mockProof) {
    return true;
  }
  const artifactDir = options.artifactDir ?? DEFAULT_ARTIFACT_DIR;
  const vkeyPath = resolveArtifact("reputation_verification_key.json", artifactDir);
  if (!vkeyPath) {
    return false;
  }
  const vkey = JSON.parse(fs.readFileSync(vkeyPath, "utf8"));
  const snarkjs = await import("snarkjs");
  return snarkjs.groth16.verify(
    vkey,
    proofBundle.publicSignals,
    proofBundle.proof
  );
}

module.exports = {
  DEFAULT_ARTIFACT_DIR,
  artifactsAvailable,
  buildCircuitInput,
  proveReputation,
  verifyReputationProof,
};
