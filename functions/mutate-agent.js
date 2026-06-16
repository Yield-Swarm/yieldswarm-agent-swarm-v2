/**
 * Paradigm Shift ($PDs^1$) — Chainlink Functions execution payload.
 *
 * Links a verified entropy block hash back to the on-chain agent mutation cycle.
 * Deploy as the JS source for a Chainlink Functions DON subscription.
 *
 * Expected secrets (Functions secrets slot):
 *   - MUTATION_WEBHOOK_URL: YieldSwarm backend mutation endpoint
 *   - MUTATION_AUTH_TOKEN: bearer token for webhook
 *
 * Expected args (Functions args):
 *   args[0] = agentTokenId (uint256 string)
 *   args[1] = blockVerificationHash (hex)
 *   args[2] = genesisHash (hex, optional)
 */

/** @param {string} url @param {object} init */
async function safeFetch(url, init) {
  if (typeof fetch !== "function") {
    throw new Error("fetch is not available in this runtime");
  }
  return fetch(url, init);
}

/**
 * Chainlink Functions entrypoint.
 * @param {object} params
 * @returns {Promise<string>} ABI-encoded string response for on-chain callback
 */
export async function mutateAgent(params) {
  const tokenId = params.args?.[0];
  const blockVerificationHash = params.args?.[1];
  const genesisHash = params.args?.[2] || "";

  if (!tokenId || !blockVerificationHash) {
    throw new Error("args[0]=tokenId and args[1]=blockVerificationHash required");
  }

  if (!/^0x[a-fA-F0-9]{64}$/.test(blockVerificationHash) && !/^[a-fA-F0-9]{64}$/.test(blockVerificationHash)) {
    throw new Error("blockVerificationHash must be 32-byte hex");
  }

  const webhookUrl = params.secrets?.MUTATION_WEBHOOK_URL || process.env.MUTATION_WEBHOOK_URL;
  const authToken = params.secrets?.MUTATION_AUTH_TOKEN || process.env.MUTATION_AUTH_TOKEN;

  if (!webhookUrl) {
    throw new Error("MUTATION_WEBHOOK_URL secret required");
  }

  const hash = blockVerificationHash.startsWith("0x")
    ? blockVerificationHash
    : `0x${blockVerificationHash}`;

  const body = {
    type: "agent_mutation",
    tokenId: String(tokenId),
    blockVerificationHash: hash,
    genesisHash: genesisHash || null,
    verifiedAt: new Date().toISOString(),
    source: "chainlink-functions",
  };

  const res = await safeFetch(webhookUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(authToken ? { Authorization: `Bearer ${authToken}` } : {}),
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`mutation webhook failed: HTTP ${res.status} ${text}`);
  }

  const result = await res.json().catch(() => ({}));

  // Return digest for on-chain callback recording.
  return JSON.stringify({
    ok: true,
    tokenId: String(tokenId),
    blockVerificationHash: hash,
    mutationId: result.mutationId || result.id || null,
  });
}

// Chainlink Functions runtime invokes the default export.
export default mutateAgent;

// Node.js direct invocation for local testing:
//   node functions/mutate-agent.js <tokenId> <blockHash>
if (import.meta.url === `file://${process.argv[1]}`) {
  const [, , tokenId, blockHash] = process.argv;
  mutateAgent({
    args: [tokenId, blockHash],
    secrets: {
      MUTATION_WEBHOOK_URL: process.env.MUTATION_WEBHOOK_URL,
      MUTATION_AUTH_TOKEN: process.env.MUTATION_AUTH_TOKEN,
    },
  })
    .then((out) => {
      console.log(out);
      process.exit(0);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
