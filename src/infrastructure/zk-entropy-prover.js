/**
 * Off-chain Groth16 prover for entropy telemetry windows.
 * Requires compiled artifacts from circuits/ (see docs/ZK_ENTROPY_SETUP.md).
 */

const fs = require("node:fs");
const path = require("node:path");
const {
  computeCommitment,
  buildCircuitInput,
  computeQualityFromWindow,
} = require("./entropy-circuit-inputs");

const DEFAULT_ARTIFACT_DIR = path.join(__dirname, "../../circuits/build");

function resolveArtifact(fileName, artifactDir = DEFAULT_ARTIFACT_DIR) {
  const full = path.join(artifactDir, fileName);
  if (!fs.existsSync(full)) {
    throw new Error(
      `Missing ZK artifact ${full}. Run: cd circuits && npm run compile`
    );
  }
  return full;
}

/**
 * Enrich entropy-core output with Poseidon commitment + validated quality.
 * @param {{ seed: string, quality: number, zkInputs: { public: object, private: object } }} result
 */
async function prepareZkInputs(result) {
  const window = result.zkInputs.private.telemetryWindow;
  const commitment = await computeCommitment(window);
  const quality = computeQualityFromWindow(window);

  if (quality !== result.quality) {
    throw new Error(`Quality mismatch: core=${result.quality} circuit=${quality}`);
  }

  result.commitment = commitment;
  result.zkInputs.public.commitment = commitment;
  result.zkInputs.public.quality = quality;

  return result;
}

/**
 * Generate a Groth16 proof for an entropy window.
 * @param {{ zkInputs: { public: object, private: object } }} entropyResult
 * @param {{ artifactDir?: string, logger?: Console }} [options]
 */
async function proveEntropy(entropyResult, options = {}) {
  const artifactDir = options.artifactDir ?? DEFAULT_ARTIFACT_DIR;
  const wasmPath = resolveArtifact("entropy_proof_js/entropy_proof.wasm", artifactDir);
  const zkeyPath = resolveArtifact("entropy_proof_final.zkey", artifactDir);

  const prepared = await prepareZkInputs({ ...entropyResult });
  const input = buildCircuitInput(
    prepared.zkInputs.private,
    prepared.zkInputs.public
  );

  const snarkjs = await import("snarkjs");
  const { proof, publicSignals } = await snarkjs.groth16.fullProve(
    input,
    wasmPath,
    zkeyPath
  );

  return {
    seed: prepared.seed ?? entropyResult.seed,
    quality: prepared.quality,
    commitment: prepared.commitment,
    proof,
    publicSignals,
    calldata: await exportSolidityCalldata(proof, publicSignals),
  };
}

/**
 * Pack proof + public signals for MutationController.submitEntropyProof.
 */
async function exportSolidityCalldata(proof, publicSignals) {
  const snarkjs = await import("snarkjs");
  const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
  const [a, b, c, inputs] = JSON.parse(`[${calldata}]`);
  return { a, b, c, publicSignals: inputs };
}

/**
 * Verify proof locally (CI / integration without chain).
 */
async function verifyEntropyProofLocally(proofBundle, options = {}) {
  const artifactDir = options.artifactDir ?? DEFAULT_ARTIFACT_DIR;
  const vkeyPath = resolveArtifact("verification_key.json", artifactDir);
  const vkey = JSON.parse(fs.readFileSync(vkeyPath, "utf8"));
  const snarkjs = await import("snarkjs");
  return snarkjs.groth16.verify(vkey, proofBundle.publicSignals, proofBundle.proof);
}

module.exports = {
  DEFAULT_ARTIFACT_DIR,
  prepareZkInputs,
  proveEntropy,
  exportSolidityCalldata,
  verifyEntropyProofLocally,
};
