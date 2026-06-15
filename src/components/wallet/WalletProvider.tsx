"use client";

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  createWalletClient,
  custom,
  parseUnits,
  type WalletClient,
} from "viem";
import { BrowserProvider, Contract } from "ethers";
import {
  Connection,
  PublicKey,
  SystemProgram,
  Transaction as SolTransaction,
  LAMPORTS_PER_SOL,
} from "@solana/web3.js";

export interface EvmConnection {
  address: string;
  chainId: number;
}
export interface SolanaConnection {
  address: string;
}

interface WalletContextValue {
  evm?: EvmConnection;
  solana?: SolanaConnection;
  connecting: string | null;
  error: string | null;
  connectEvm: () => Promise<EvmConnection | null>;
  connectSolana: () => Promise<SolanaConnection | null>;
  signEvm: (message: string) => Promise<string>;
  signSolana: (message: string) => Promise<string>;
  sendEvmDeposit: (opts: {
    to: string;
    amount: string;
    decimals: number;
    erc20?: string;
  }) => Promise<string>;
  sendSolanaDeposit: (opts: { to: string; amount: string }) => Promise<string>;
}

const WalletContext = createContext<WalletContextValue | null>(null);

const SOLANA_RPC =
  process.env.NEXT_PUBLIC_SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com";

const ERC20_ABI = ["function transfer(address to, uint256 amount) returns (bool)"];

export function WalletProvider({ children }: { children: ReactNode }) {
  const [evm, setEvm] = useState<EvmConnection>();
  const [solana, setSolana] = useState<SolanaConnection>();
  const [connecting, setConnecting] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const getEvmClient = useCallback((): WalletClient => {
    if (!window.ethereum) throw new Error("No EVM wallet found (install MetaMask)");
    return createWalletClient({ transport: custom(window.ethereum) });
  }, []);

  const connectEvm = useCallback(async () => {
    setError(null);
    setConnecting("evm");
    try {
      if (!window.ethereum) throw new Error("No EVM wallet found (install MetaMask)");
      const client = getEvmClient();
      const [address] = await client.requestAddresses();
      const chainIdHex = await window.ethereum.request<string>({ method: "eth_chainId" });
      const conn = { address, chainId: parseInt(chainIdHex, 16) };
      setEvm(conn);
      return conn;
    } catch (e) {
      setError((e as Error).message);
      return null;
    } finally {
      setConnecting(null);
    }
  }, [getEvmClient]);

  const connectSolana = useCallback(async () => {
    setError(null);
    setConnecting("solana");
    try {
      if (!window.solana) throw new Error("No Solana wallet found (install Phantom)");
      const res = await window.solana.connect();
      const conn = { address: res.publicKey.toBase58() };
      setSolana(conn);
      return conn;
    } catch (e) {
      setError((e as Error).message);
      return null;
    } finally {
      setConnecting(null);
    }
  }, []);

  const signEvm = useCallback(
    async (message: string) => {
      const client = getEvmClient();
      const account = evm?.address ?? (await client.requestAddresses())[0];
      return client.signMessage({ account: account as `0x${string}`, message });
    },
    [evm, getEvmClient],
  );

  const signSolana = useCallback(async (message: string) => {
    if (!window.solana) throw new Error("No Solana wallet found");
    const encoded = new TextEncoder().encode(message);
    const { signature } = await window.solana.signMessage(encoded, "utf8");
    // base64-encode the raw signature for the server.
    let bin = "";
    for (const b of signature) bin += String.fromCharCode(b);
    return btoa(bin);
  }, []);

  const sendEvmDeposit = useCallback(
    async (opts: { to: string; amount: string; decimals: number; erc20?: string }) => {
      if (!window.ethereum) throw new Error("No EVM wallet found");
      const provider = new BrowserProvider(window.ethereum as never);
      const signer = await provider.getSigner();
      if (opts.erc20) {
        const token = new Contract(opts.erc20, ERC20_ABI, signer);
        const tx = await token.transfer(opts.to, parseUnits(opts.amount, opts.decimals));
        return tx.hash as string;
      }
      const tx = await signer.sendTransaction({
        to: opts.to,
        value: parseUnits(opts.amount, opts.decimals),
      });
      return tx.hash;
    },
    [],
  );

  const sendSolanaDeposit = useCallback(
    async (opts: { to: string; amount: string }) => {
      if (!window.solana?.publicKey) throw new Error("Solana wallet not connected");
      const connection = new Connection(SOLANA_RPC, "confirmed");
      const fromPubkey = window.solana.publicKey;
      const tx = new SolTransaction().add(
        SystemProgram.transfer({
          fromPubkey,
          toPubkey: new PublicKey(opts.to),
          lamports: Math.round(Number(opts.amount) * LAMPORTS_PER_SOL),
        }),
      );
      tx.feePayer = fromPubkey;
      tx.recentBlockhash = (await connection.getLatestBlockhash()).blockhash;
      const { signature } = await window.solana.signAndSendTransaction(tx);
      return signature;
    },
    [],
  );

  const value = useMemo<WalletContextValue>(
    () => ({
      evm,
      solana,
      connecting,
      error,
      connectEvm,
      connectSolana,
      signEvm,
      signSolana,
      sendEvmDeposit,
      sendSolanaDeposit,
    }),
    [
      evm,
      solana,
      connecting,
      error,
      connectEvm,
      connectSolana,
      signEvm,
      signSolana,
      sendEvmDeposit,
      sendSolanaDeposit,
    ],
  );

  return <WalletContext.Provider value={value}>{children}</WalletContext.Provider>;
}

export function useWallet(): WalletContextValue {
  const ctx = useContext(WalletContext);
  if (!ctx) throw new Error("useWallet must be used within WalletProvider");
  return ctx;
}
