import { evmRpc, NEXUS_TREASURY_SOLANA, solanaRpc, TREASURY_EVM, TREASURY_IOTEX } from "./config";

export interface ChainBalance {
  chain: string;
  address: string;
  balance: string;
  balanceUsd: number | null;
  live: boolean;
  error?: string;
}

async function fetchJson<T>(url: string, init?: RequestInit): Promise<T | null> {
  try {
    const res = await fetch(url, { ...init, next: { revalidate: 30 } });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

export async function fetchSolanaBalance(address: string): Promise<ChainBalance> {
  const rpc = solanaRpc();
  if (!rpc || !address) {
    return { chain: "Solana", address, balance: "—", balanceUsd: null, live: false, error: "no rpc" };
  }
  try {
    const res = await fetch(rpc, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getBalance", params: [address] }),
      next: { revalidate: 30 },
    });
    const data = await res.json();
    const lamports = data?.result?.value ?? 0;
    const sol = lamports / 1e9;
    const balanceUsd = sol * 150; // spot estimate when price API offline
    return {
      chain: "Solana (Nexus)",
      address,
      balance: `${sol.toFixed(4)} SOL`,
      balanceUsd,
      live: true,
    };
  } catch (e) {
    return {
      chain: "Solana (Nexus)",
      address,
      balance: "—",
      balanceUsd: null,
      live: false,
      error: e instanceof Error ? e.message : "rpc error",
    };
  }
}

export async function fetchEvmBalance(address: string): Promise<ChainBalance> {
  if (!address) {
    return { chain: "EVM", address: "", balance: "—", balanceUsd: null, live: false };
  }
  try {
    const res = await fetch(evmRpc(), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "eth_getBalance",
        params: [address, "latest"],
      }),
      next: { revalidate: 30 },
    });
    const data = await res.json();
    const wei = BigInt(data?.result || "0x0");
    const eth = Number(wei) / 1e18;
    return {
      chain: "EVM",
      address,
      balance: `${eth.toFixed(4)} ETH`,
      balanceUsd: eth * 3200,
      live: true,
    };
  } catch (e) {
    return {
      chain: "EVM",
      address,
      balance: "—",
      balanceUsd: null,
      live: false,
      error: e instanceof Error ? e.message : "rpc error",
    };
  }
}

export async function fetchIotexBalance(address: string): Promise<ChainBalance> {
  if (!address) {
    return {
      chain: "IoTeX",
      address: "",
      balance: "—",
      balanceUsd: null,
      live: false,
      error: "IOTEX_TREASURY_ADDRESS not configured",
    };
  }
  const data = await fetchJson<{ account?: { balance?: string } }>(
    `https://babel-api.mainnet.iotex.io/v1/accounts/${address}`,
  );
  if (data?.account?.balance != null) {
    const iotx = Number(data.account.balance) / 1e18;
    return {
      chain: "IoTeX",
      address,
      balance: `${iotx.toFixed(2)} IOTX`,
      balanceUsd: iotx * 0.04,
      live: true,
    };
  }
  return {
    chain: "IoTeX",
    address,
    balance: "—",
    balanceUsd: null,
    live: false,
    error: "iotex api unreachable",
  };
}

export async function fetchAllTreasuryBalances() {
  const [solana, evm, iotex] = await Promise.all([
    fetchSolanaBalance(NEXUS_TREASURY_SOLANA),
    fetchEvmBalance(TREASURY_EVM),
    fetchIotexBalance(TREASURY_IOTEX),
  ]);
  return { solana, evm, iotex };
}
