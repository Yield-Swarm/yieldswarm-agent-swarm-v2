/**
 * Crypto off-ramp — send funds from our hot wallet to a user's wallet address.
 *
 * EVM    -> ethers.js (native + ERC-20)
 * Solana -> @solana/web3.js (native SOL)
 *
 * SPL-token and TON sends require additional signing infra (@solana/spl-token,
 * @ton/ton mnemonic wallet) and are intentionally gated with a clear error
 * rather than silently failing.
 */

import {
  JsonRpcProvider,
  Wallet,
  Contract,
  parseUnits,
  isAddress,
} from "ethers";
import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction as SolTransaction,
  sendAndConfirmTransaction,
  LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import { serverEnv } from "@/lib/config/env";
import { Chain } from "@/lib/db/models";
import { EVM_CHAINS, findAsset } from "@/lib/web3/chains";

export interface WithdrawResult {
  txHash: string;
  chain: Chain;
  explorerUrl?: string;
}

const ERC20_ABI = [
  "function transfer(address to, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
];

export async function withdrawEvm(params: {
  chainId: number;
  to: string;
  amount: string;
  assetSymbol: string;
}): Promise<WithdrawResult> {
  const { chainId, to, amount, assetSymbol } = params;
  if (!isAddress(to)) throw new Error("Invalid EVM destination address");

  const chainDef = EVM_CHAINS[chainId];
  if (!chainDef) throw new Error(`Unsupported EVM chain ${chainId}`);
  const asset = findAsset("evm", assetSymbol, chainId);
  if (!asset) throw new Error(`Unknown asset ${assetSymbol}`);

  const pk = serverEnv.web3.hotWallet.evmPrivateKey();
  if (!pk) throw new Error("HOT_WALLET_EVM_PRIVATE_KEY not configured");

  const provider = new JsonRpcProvider(serverEnv.web3.evmRpcUrls()[chainId]);
  const wallet = new Wallet(pk, provider);

  let hash: string;
  if (asset.native) {
    const tx = await wallet.sendTransaction({
      to,
      value: parseUnits(amount, asset.decimals),
    });
    hash = tx.hash;
  } else {
    const token = new Contract(asset.erc20!, ERC20_ABI, wallet);
    const tx = await token.transfer(to, parseUnits(amount, asset.decimals));
    hash = tx.hash;
  }

  return {
    txHash: hash,
    chain: "evm",
    explorerUrl: `${chainDef.explorer}/tx/${hash}`,
  };
}

function loadSolanaKeypair(): Keypair {
  const raw = serverEnv.web3.hotWallet.solanaSecretKey();
  if (!raw) throw new Error("HOT_WALLET_SOLANA_SECRET_KEY not configured");
  let bytes: Uint8Array;
  if (raw.trim().startsWith("[")) {
    bytes = Uint8Array.from(JSON.parse(raw));
  } else {
    bytes = Uint8Array.from(Buffer.from(raw.trim(), "base64"));
  }
  return Keypair.fromSecretKey(bytes);
}

export async function withdrawSolana(params: {
  to: string;
  amount: string;
  assetSymbol: string;
}): Promise<WithdrawResult> {
  const { to, amount, assetSymbol } = params;
  const asset = findAsset("solana", assetSymbol);
  if (!asset) throw new Error(`Unknown asset ${assetSymbol}`);
  if (!asset.native) {
    throw new Error(
      "SPL-token withdrawals require @solana/spl-token; only native SOL is enabled",
    );
  }

  const connection = new Connection(serverEnv.web3.solanaRpcUrl(), "confirmed");
  const payer = loadSolanaKeypair();
  let toPubkey: PublicKey;
  try {
    toPubkey = new PublicKey(to);
  } catch {
    throw new Error("Invalid Solana destination address");
  }

  const lamports = BigInt(Math.round(Number(amount) * LAMPORTS_PER_SOL));
  const tx = new SolTransaction().add(
    SystemProgram.transfer({
      fromPubkey: payer.publicKey,
      toPubkey,
      lamports: Number(lamports),
    }),
  );
  const signature = await sendAndConfirmTransaction(connection, tx, [payer]);
  return {
    txHash: signature,
    chain: "solana",
    explorerUrl: `https://solscan.io/tx/${signature}`,
  };
}

export async function withdrawCrypto(params: {
  chain: Chain;
  to: string;
  amount: string;
  assetSymbol: string;
  evmChainId?: number;
}): Promise<WithdrawResult> {
  if (params.chain === "evm") {
    return withdrawEvm({
      chainId: params.evmChainId ?? 1,
      to: params.to,
      amount: params.amount,
      assetSymbol: params.assetSymbol,
    });
  }
  if (params.chain === "solana") {
    return withdrawSolana({
      to: params.to,
      amount: params.amount,
      assetSymbol: params.assetSymbol,
    });
  }
  throw new Error(
    "TON withdrawals require a @ton/ton mnemonic wallet and are not enabled in this build",
  );
}
