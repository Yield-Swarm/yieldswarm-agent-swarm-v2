/**
 * TV dashboard — treasury addresses and domain inventory.
 * Values load from process.env (Cursor secrets / Vault injection).
 */

export const AGENT_TARGET = Number(process.env.AGENT_COUNT_TOTAL || "10080");
export const VAULT_TARGET_USD = Number(process.env.VAULT_TARGET_USD || "5000000");

/** Primary Nexus Treasury on Solana (Solenoid 1). */
export const NEXUS_TREASURY_SOLANA =
  process.env.TREASURY_SOLANA_ADDRESS ||
  process.env.NEXUS_TREASURY_SOLANA ||
  "kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN";

export const TREASURY_EVM =
  process.env.TREASURY_EVM_ADDRESS ||
  process.env.EMISSION_ROUTER_EVM_ADDRESS ||
  "0x9505578Bd5b32468E3cEa632664F7b8d2e46128c";

export const TREASURY_TON = process.env.TREASURY_TON_ADDRESS || "";

/** IoTeX treasury — set via Vault / SecretProd injection. */
export const TREASURY_IOTEX =
  process.env.IOTEX_TREASURY_ADDRESS ||
  process.env.TREASURY_IOTEX_ADDRESS ||
  "";

export const MINING_ROOTS = [
  { chain: "Base ETC", address: "0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00" },
  { chain: "ZEC", address: "t1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY" },
  { chain: "PRL", address: "29L3dA5XvXUthBJeanarcTij6e5fdtAD81PxQMfEEQQ9" },
  { chain: "TAO", address: "5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF" },
  { chain: "Base HYPE", address: "0x856e90EDd6d167355FcB6c35a8A857FFCA011Aa0" },
  { chain: "Base cbETH", address: "0x455156dFDc95084A8e84e8d734a036A9a2e11Af0" },
  { chain: "Base BTC", address: "0x1353f846DB707F6739591d294c80740607F1A87a" },
] as const;

export const DOMAINS = [
  {
    id: "official",
    label: "yieldswarm.xyz",
    host: "yieldswarm.xyz",
    url: "https://yieldswarm.xyz",
    kind: "official" as const,
  },
  {
    id: "helix",
    label: "helixchain",
    host: "helixchain.blockchain",
    kind: "unstoppable" as const,
  },
  {
    id: "nexus",
    label: "nexuschain.blockchain",
    host: "nexuschain.blockchain",
    kind: "unstoppable" as const,
  },
  {
    id: "shadow",
    label: "shadowchain.blockchain",
    host: "shadowchain.blockchain",
    kind: "unstoppable" as const,
  },
] as const;

export function backendBase(): string {
  return (
    process.env.BACKEND_URL ||
    process.env.API_BASE ||
    process.env.ARENA_API_BASE ||
    "http://127.0.0.1:8080"
  ).replace(/\/$/, "");
}

export function solanaRpc(): string {
  const key = process.env.HELIUS_API_KEY;
  if (key && !process.env.SOLANA_RPC_URL?.includes("helius")) {
    return `https://mainnet.helius-rpc.com/?api-key=${key}`;
  }
  return process.env.SOLANA_RPC_URL || process.env.NEXT_PUBLIC_SOLANA_RPC_URL || "";
}

export function evmRpc(): string {
  return (
    process.env.QUICKNODE_RPC_URL ||
    process.env.ETHEREUM_RPC_URL ||
    process.env.EVM_RPC_URL ||
    "https://eth.llamarpc.com"
  );
}
