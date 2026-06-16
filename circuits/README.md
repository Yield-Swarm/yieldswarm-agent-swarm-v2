# Entropy proof circuit — ZK¹ Verifiable + PDs¹ Paradigm Shift
#
# Build (requires circom + circomlib):
#   cd circuits && npm install
#   npm run compile
#   bash ../scripts/zk-trusted-setup.sh
#
# Proves telemetry readings are within policy without exposing raw metrics.
# Public: commitment (Poseidon), vramMaxScaled, tempMaxScaled
# Private: vramScaled, tempScaled, nonce
