/**
 * Solana program IDs — production (sync with Anchor.toml).
 * Do NOT use placeholder declare_id strings from generic god prompts.
 */
export const PROGRAM_IDS = {
  crossChain: '9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt',
  swarmOps: '6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz',
  coordinator: 'DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p',
  arena: 'F1cnaQtFrqyp6x4oejdqMULsvejcznkJryXd6SbVSmp3',
} as const;

export const CHAIN_IDS = {
  HELIX: 1,
  SOLANA: 2,
  ETHEREUM: 3,
  IOTEX: 4689,
  BASE: 8453,
} as const;
