# ZK entropy / Mayhem Mode scheduler — sourced from env
# Used by: node src/automation/zk-mutation-scheduler.js
ZK_MAYHEM_ENABLED=${ZK_MAYHEM_ENABLED:-1}
ZK_MIN_ENTROPY_QUALITY=${ZK_MIN_ENTROPY_QUALITY:-0.5}
ZK_MUTATION_INTERVAL_MS=${ZK_MUTATION_INTERVAL_MS:-604800000}
MUTATION_WEBHOOK_URL=${MUTATION_WEBHOOK_URL}
ZK__CIRCUIT_WASM=${ZK__CIRCUIT_WASM:-./circuits/build/entropy_proof_js/entropy_proof.wasm}
ZK__ZKEY_PATH=${ZK__ZKEY_PATH:-./circuits/build/entropy_proof_final.zkey}
MUTATION_CONTROLLER_ADDRESS=${MUTATION_CONTROLLER_ADDRESS}
