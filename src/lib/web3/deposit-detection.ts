/**
 * On-chain deposit detection.
 *
 * Given a tx hash/signature that a user claims sent funds to one of our
 * treasury addresses, we independently verify it against the chain:
 *   - the destination really is our treasury,
 *   - the asset + amount,
 *   - and that it has enough confirmations to be considered settled.
 *
 * EVM   -> viem public client
 * Solana -> @solana/web3.js Connection
 * TON   -> tonapi.io REST
 */

import {
  createPublicClient,
  http,
  formatUnits,
  getAddress,
  decodeEventLog,
  type Hash,
} from "viem";
import { Connection, PublicKey } from "@solana/web3.js";
import { serverEnv } from "@/lib/config/env";
import { Chain } from "@/lib/db/models";
import { EVM_CHAINS, SOLANA_CHAIN, TON_CHAIN, findAsset } from "@/lib/web3/chains";

export interface DepositDetectionResult {
  found: boolean;
  confirmed: boolean;
  confirmations?: number;
  amount?: string;
  asset?: string;
  from?: string;
  to?: string;
  txHash: string;
  chain: Chain;
  reason?: string;
}

const ERC20_TRANSFER_ABI = [
  {
    type: "event",
    name: "Transfer",
    inputs: [
      { name: "from", type: "address", indexed: true },
      { name: "to", type: "address", indexed: true },
      { name: "value", type: "uint256", indexed: false },
    ],
  },
] as const;

export async function detectEvmDeposit(params: {
  chainId: number;
  txHash: string;
  treasury: string;
  assetSymbol: string;
}): Promise<DepositDetectionResult> {
  const { chainId, txHash, treasury, assetSymbol } = params;
  const base: DepositDetectionResult = { found: false, confirmed: false, txHash, chain: "evm" };

  const chainDef = EVM_CHAINS[chainId];
  if (!chainDef) return { ...base, reason: `Unsupported EVM chain ${chainId}` };
  const asset = findAsset("evm", assetSymbol, chainId);
  if (!asset) return { ...base, reason: `Unknown asset ${assetSymbol}` };

  const rpc = serverEnv.web3.evmRpcUrls()[chainId];
  const client = createPublicClient({ transport: http(rpc) });

  const [tx, receipt, head] = await Promise.all([
    client.getTransaction({ hash: txHash as Hash }).catch(() => null),
    client.getTransactionReceipt({ hash: txHash as Hash }).catch(() => null),
    client.getBlockNumber(),
  ]);

  if (!tx || !receipt) return { ...base, reason: "Transaction not found or not yet mined" };

  const confirmations = Number(head - receipt.blockNumber) + 1;
  const minConf = serverEnv.web3.confirmations();
  const treasuryAddr = getAddress(treasury);

  if (receipt.status !== "success") {
    return { ...base, found: true, confirmations, reason: "Transaction reverted" };
  }

  if (asset.native) {
    if (!tx.to || getAddress(tx.to) !== treasuryAddr) {
      return { ...base, found: true, confirmations, reason: "Not sent to treasury" };
    }
    return {
      found: true,
      confirmed: confirmations >= minConf,
      confirmations,
      amount: formatUnits(tx.value, asset.decimals),
      asset: asset.symbol,
      from: getAddress(tx.from),
      to: treasuryAddr,
      txHash,
      chain: "evm",
    };
  }

  // ERC-20: find a Transfer log from the token contract to the treasury.
  const tokenAddr = getAddress(asset.erc20!);
  for (const log of receipt.logs) {
    if (getAddress(log.address) !== tokenAddr) continue;
    try {
      const decoded = decodeEventLog({
        abi: ERC20_TRANSFER_ABI,
        data: log.data,
        topics: log.topics,
      });
      if (decoded.eventName !== "Transfer") continue;
      const args = decoded.args as { from: string; to: string; value: bigint };
      if (getAddress(args.to) !== treasuryAddr) continue;
      return {
        found: true,
        confirmed: confirmations >= minConf,
        confirmations,
        amount: formatUnits(args.value, asset.decimals),
        asset: asset.symbol,
        from: getAddress(args.from),
        to: treasuryAddr,
        txHash,
        chain: "evm",
      };
    } catch {
      // not a Transfer log; keep scanning
    }
  }
  return { ...base, found: true, confirmations, reason: "No matching token transfer to treasury" };
}

export async function detectSolanaDeposit(params: {
  txSignature: string;
  treasury: string;
  assetSymbol: string;
}): Promise<DepositDetectionResult> {
  const { txSignature, treasury, assetSymbol } = params;
  const base: DepositDetectionResult = {
    found: false,
    confirmed: false,
    txHash: txSignature,
    chain: "solana",
  };

  const asset = findAsset("solana", assetSymbol);
  if (!asset) return { ...base, reason: `Unknown asset ${assetSymbol}` };

  const connection = new Connection(serverEnv.web3.solanaRpcUrl(), "confirmed");
  const tx = await connection
    .getParsedTransaction(txSignature, { maxSupportedTransactionVersion: 0 })
    .catch(() => null);
  if (!tx || !tx.meta) return { ...base, reason: "Transaction not found" };
  if (tx.meta.err) return { ...base, found: true, reason: "Transaction failed on-chain" };

  const statuses = await connection
    .getSignatureStatuses([txSignature])
    .catch(() => null);
  const status = statuses?.value?.[0];
  const confirmed =
    status?.confirmationStatus === "finalized" || status?.confirmationStatus === "confirmed";
  const confirmations = status?.confirmations ?? undefined;

  const accountKeys = tx.transaction.message.accountKeys.map((k) =>
    typeof k === "string" ? k : k.pubkey.toBase58(),
  );
  const treasuryKey = new PublicKey(treasury).toBase58();
  const signer = accountKeys[0];

  if (asset.native) {
    const idx = accountKeys.indexOf(treasuryKey);
    if (idx === -1) return { ...base, found: true, reason: "Treasury not in account list" };
    const delta = (tx.meta.postBalances[idx] ?? 0) - (tx.meta.preBalances[idx] ?? 0);
    if (delta <= 0) return { ...base, found: true, reason: "No SOL credited to treasury" };
    return {
      found: true,
      confirmed,
      confirmations: confirmations ?? undefined,
      amount: formatUnits(BigInt(delta), asset.decimals),
      asset: asset.symbol,
      from: signer,
      to: treasuryKey,
      txHash: txSignature,
      chain: "solana",
    };
  }

  // SPL token: compare pre/post token balances for owner == treasury, mint == asset.
  const pre = tx.meta.preTokenBalances ?? [];
  const post = tx.meta.postTokenBalances ?? [];
  const match = post.find(
    (b) => b.owner === treasuryKey && b.mint === asset.splMint,
  );
  if (!match) return { ...base, found: true, reason: "No matching SPL credit to treasury" };
  const before = pre.find((b) => b.accountIndex === match.accountIndex);
  const beforeAmt = BigInt(before?.uiTokenAmount.amount ?? "0");
  const afterAmt = BigInt(match.uiTokenAmount.amount ?? "0");
  const delta = afterAmt - beforeAmt;
  if (delta <= 0n) return { ...base, found: true, reason: "No token credited to treasury" };
  return {
    found: true,
    confirmed,
    confirmations: confirmations ?? undefined,
    amount: formatUnits(delta, asset.decimals),
    asset: asset.symbol,
    from: signer,
    to: treasuryKey,
    txHash: txSignature,
    chain: "solana",
  };
}

export async function detectTonDeposit(params: {
  txHash: string;
  treasury: string;
  assetSymbol: string;
}): Promise<DepositDetectionResult> {
  const { txHash, treasury, assetSymbol } = params;
  const base: DepositDetectionResult = { found: false, confirmed: false, txHash, chain: "ton" };

  const asset = findAsset("ton", assetSymbol);
  if (!asset) return { ...base, reason: `Unknown asset ${assetSymbol}` };
  // Jetton (USDT) deposit parsing is best-effort; native TON is fully supported.

  const headers: Record<string, string> = { Accept: "application/json" };
  const apiKey = serverEnv.web3.tonApiKey();
  if (apiKey) headers.Authorization = `Bearer ${apiKey}`;

  const res = await fetch(
    `${serverEnv.web3.tonApiBase()}/v2/blockchain/transactions/${encodeURIComponent(txHash)}`,
    { headers, cache: "no-store" },
  ).catch(() => null);
  if (!res || !res.ok) return { ...base, reason: "Transaction not found" };
  const data: any = await res.json().catch(() => null);
  if (!data) return { ...base, reason: "Malformed tonapi response" };

  const inMsg = data.in_msg;
  if (!inMsg) return { ...base, found: true, reason: "No inbound message" };

  const dest: string | undefined = inMsg.destination?.address ?? inMsg.destination;
  if (!dest || !sameTonAddress(dest, treasury)) {
    return { ...base, found: true, reason: "Not sent to treasury" };
  }

  const value = BigInt(inMsg.value ?? 0);
  if (value <= 0n) return { ...base, found: true, reason: "Zero value transfer" };

  return {
    found: true,
    confirmed: Boolean(data.success ?? true),
    amount: formatUnits(value, 9),
    asset: "TON",
    from: inMsg.source?.address ?? inMsg.source,
    to: dest,
    txHash,
    chain: "ton",
  };
}

function sameTonAddress(a: string, b: string): boolean {
  // tonapi may return raw "0:hash"; compare case-insensitively and trust caller
  // to provide a comparable form. Best-effort normalisation.
  return a.toLowerCase().replace(/^0:/, "") === b.toLowerCase().replace(/^0:/, "");
}

export async function detectDeposit(params: {
  chain: Chain;
  txHash: string;
  assetSymbol: string;
  evmChainId?: number;
}): Promise<DepositDetectionResult> {
  if (params.chain === "evm") {
    const treasury = serverEnv.web3.treasury.evm();
    if (!treasury) throw new Error("TREASURY_EVM_ADDRESS not configured");
    return detectEvmDeposit({
      chainId: params.evmChainId ?? 1,
      txHash: params.txHash,
      treasury,
      assetSymbol: params.assetSymbol,
    });
  }
  if (params.chain === "solana") {
    const treasury = serverEnv.web3.treasury.solana();
    if (!treasury) throw new Error("TREASURY_SOLANA_ADDRESS not configured");
    return detectSolanaDeposit({
      txSignature: params.txHash,
      treasury,
      assetSymbol: params.assetSymbol,
    });
  }
  const treasury = serverEnv.web3.treasury.ton();
  if (!treasury) throw new Error("TREASURY_TON_ADDRESS not configured");
  return detectTonDeposit({
    txHash: params.txHash,
    treasury,
    assetSymbol: params.assetSymbol,
  });
}

export const SUPPORTED_DEPOSIT_CHAINS = {
  evm: Object.keys(EVM_CHAINS).map(Number),
  solana: SOLANA_CHAIN.name,
  ton: TON_CHAIN.name,
};
