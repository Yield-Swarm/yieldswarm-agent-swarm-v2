/**
 * Solana adapter using `@solana/web3.js` for RPC and the wallet's injected
 * provider (Phantom / Solflare / Backpack) for signing. Supports native SOL
 * transfers and read-only SPL token balances via parsed RPC accounts.
 */
import {
  Connection,
  PublicKey,
  SystemProgram,
  Transaction,
} from "@solana/web3.js";

import { walletConfig } from "../config";
import { DEFAULT_CHAIN, explorerTxUrl, getChain } from "../chains";
import { StateEmitter, session } from "./base";
import {
  WalletError,
  type AdapterState,
  type ChainAdapter,
  type TokenBalance,
  type TransactionResult,
  type TransferRequest,
  type Unsubscribe,
  type WalletAccount,
  type WalletConnector,
} from "../types";
import { formatBalance, toBaseUnits } from "../format";

interface SolanaProvider {
  publicKey?: { toString(): string } | null;
  isPhantom?: boolean;
  isSolflare?: boolean;
  isBackpack?: boolean;
  connect(opts?: { onlyIfTrusted?: boolean }): Promise<{ publicKey: { toString(): string } }>;
  disconnect(): Promise<void>;
  signMessage(message: Uint8Array, encoding?: string): Promise<{ signature: Uint8Array } | Uint8Array>;
  signAndSendTransaction(tx: Transaction): Promise<{ signature: string }>;
  on?(event: string, handler: (...args: unknown[]) => void): void;
  removeListener?(event: string, handler: (...args: unknown[]) => void): void;
}

interface SolanaConnectorDef {
  id: string;
  name: string;
  iconUrl: string;
  downloadUrl: string;
  resolve: () => SolanaProvider | undefined;
}

const CONNECTORS: SolanaConnectorDef[] = [
  {
    id: "phantom",
    name: "Phantom",
    iconUrl: "https://avatars.githubusercontent.com/u/78782331",
    downloadUrl: "https://phantom.app/download",
    resolve: () =>
      (window as any).phantom?.solana ??
      ((window as any).solana?.isPhantom ? (window as any).solana : undefined),
  },
  {
    id: "solflare",
    name: "Solflare",
    iconUrl: "https://avatars.githubusercontent.com/u/89903469",
    downloadUrl: "https://solflare.com/download",
    resolve: () => (window as any).solflare?.isSolflare ? (window as any).solflare : undefined,
  },
  {
    id: "backpack",
    name: "Backpack",
    iconUrl: "https://avatars.githubusercontent.com/u/101131736",
    downloadUrl: "https://backpack.app/download",
    resolve: () => (window as any).backpack?.isBackpack ? (window as any).backpack : undefined,
  },
];

const SOL_CHAIN = DEFAULT_CHAIN.solana;

export class SolanaAdapter implements ChainAdapter {
  readonly namespace = "solana" as const;
  private connection: Connection;
  private emitter = new StateEmitter();
  private state: AdapterState;
  private provider?: SolanaProvider;
  private activeConnectorId?: string;
  private accountChangedHandler?: (...args: unknown[]) => void;

  constructor() {
    this.connection = new Connection(walletConfig.rpc.solana, "confirmed");
    this.state = {
      namespace: "solana",
      status: "disconnected",
      account: null,
      chain: null,
    };
  }

  getConnectors(): WalletConnector[] {
    return CONNECTORS.map((c) => ({
      id: c.id,
      name: c.name,
      namespace: "solana",
      iconUrl: c.iconUrl,
      installed: typeof window !== "undefined" && !!c.resolve(),
      downloadUrl: c.downloadUrl,
    }));
  }

  private bindProviderEvents(provider: SolanaProvider): void {
    if (!provider.on) return;
    this.accountChangedHandler = (...args: unknown[]) => {
      const pk = args[0] as { toString(): string } | null;
      if (pk && this.state.account) {
        this.setConnected(pk.toString(), this.activeConnectorId!, this.state.account.walletName);
      } else {
        this.handleDisconnect();
      }
    };
    provider.on("accountChanged", this.accountChangedHandler);
  }

  private setConnected(address: string, connectorId: string, name: string): void {
    this.state = {
      namespace: "solana",
      status: "connected",
      chain: getChain(SOL_CHAIN) ?? null,
      account: {
        address,
        namespace: "solana",
        chainId: SOL_CHAIN,
        walletId: connectorId,
        walletName: name,
      },
    };
    this.emitter.emit(this.state);
  }

  private handleDisconnect(): void {
    this.state = {
      namespace: "solana",
      status: "disconnected",
      account: null,
      chain: null,
    };
    this.emitter.emit(this.state);
  }

  async autoConnect(): Promise<WalletAccount | null> {
    const last = session.load("solana");
    if (!last) return null;
    const def = CONNECTORS.find((c) => c.id === last);
    const provider = def?.resolve();
    if (!provider) return null;
    try {
      const res = await provider.connect({ onlyIfTrusted: true });
      this.provider = provider;
      this.activeConnectorId = last;
      this.bindProviderEvents(provider);
      this.setConnected(res.publicKey.toString(), last, def!.name);
      return this.state.account;
    } catch {
      session.clear("solana");
      return null;
    }
  }

  async connect(connectorId: string): Promise<WalletAccount> {
    const def = CONNECTORS.find((c) => c.id === connectorId);
    if (!def) throw new WalletError("unsupported", `Unknown Solana wallet: ${connectorId}`);
    const provider = def.resolve();
    if (!provider) {
      throw new WalletError("not_installed", `${def.name} is not installed`);
    }
    this.state = { ...this.state, status: "connecting" };
    this.emitter.emit(this.state);
    try {
      const res = await provider.connect();
      this.provider = provider;
      this.activeConnectorId = connectorId;
      this.bindProviderEvents(provider);
      session.save("solana", connectorId);
      this.setConnected(res.publicKey.toString(), connectorId, def.name);
      return this.state.account!;
    } catch (err) {
      this.handleDisconnect();
      throw normalizeSolanaError(err);
    }
  }

  async disconnect(): Promise<void> {
    session.clear("solana");
    if (this.provider?.removeListener && this.accountChangedHandler) {
      this.provider.removeListener("accountChanged", this.accountChangedHandler);
    }
    try {
      await this.provider?.disconnect();
    } catch {
      /* ignore */
    }
    this.provider = undefined;
    this.activeConnectorId = undefined;
    this.handleDisconnect();
  }

  getState(): AdapterState {
    return this.state;
  }

  async getBalance(token?: string): Promise<TokenBalance> {
    const acct = this.state.account;
    if (!acct) throw new WalletError("not_connected", "Solana wallet not connected");
    const owner = new PublicKey(acct.address);

    if (token) {
      const mint = new PublicKey(token);
      const accounts = await this.connection.getParsedTokenAccountsByOwner(owner, { mint });
      let raw = 0n;
      let decimals = 0;
      for (const { account } of accounts.value) {
        const info = (account.data as any).parsed.info.tokenAmount;
        raw += BigInt(info.amount);
        decimals = info.decimals;
      }
      return {
        raw,
        decimals,
        symbol: "SPL",
        formatted: formatBalance(raw, decimals),
        token,
      };
    }

    const lamports = await this.connection.getBalance(owner);
    const raw = BigInt(lamports);
    return {
      raw,
      decimals: 9,
      symbol: "SOL",
      formatted: formatBalance(raw, 9),
    };
  }

  async signMessage(message: string): Promise<string> {
    if (!this.provider) throw new WalletError("not_connected", "Solana wallet not connected");
    const encoded = new TextEncoder().encode(message);
    const res = await this.provider.signMessage(encoded, "utf8");
    const signature = res instanceof Uint8Array ? res : res.signature;
    return bytesToBase64(signature);
  }

  async sendTransfer(request: TransferRequest): Promise<TransactionResult> {
    const acct = this.state.account;
    if (!acct || !this.provider) {
      throw new WalletError("not_connected", "Solana wallet not connected");
    }
    if (request.token) {
      throw new WalletError(
        "unsupported",
        "SPL token transfers are read-only in this build; use native SOL transfers.",
      );
    }
    try {
      const from = new PublicKey(acct.address);
      const to = new PublicKey(request.to);
      const lamports = toBaseUnits(request.amount, 9);
      const tx = new Transaction().add(
        SystemProgram.transfer({
          fromPubkey: from,
          toPubkey: to,
          lamports: Number(lamports),
        }),
      );
      const { blockhash } = await this.connection.getLatestBlockhash();
      tx.recentBlockhash = blockhash;
      tx.feePayer = from;
      const { signature } = await this.provider.signAndSendTransaction(tx);
      const chain = getChain(SOL_CHAIN);
      return {
        hash: signature,
        chainId: SOL_CHAIN,
        explorerUrl: chain ? explorerTxUrl(chain, signature) : undefined,
      };
    } catch (err) {
      throw normalizeSolanaError(err);
    }
  }

  subscribe(listener: (state: AdapterState) => void): Unsubscribe {
    return this.emitter.subscribe(listener);
  }

  destroy(): void {
    if (this.provider?.removeListener && this.accountChangedHandler) {
      this.provider.removeListener("accountChanged", this.accountChangedHandler);
    }
    this.emitter.clear();
  }
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return typeof btoa !== "undefined" ? btoa(binary) : Buffer.from(bytes).toString("base64");
}

function normalizeSolanaError(err: unknown): WalletError {
  const message = err instanceof Error ? err.message : String(err);
  if (/reject|denied|cancel|user/i.test(message)) {
    return new WalletError("rejected", "Request rejected in wallet", err);
  }
  return new WalletError("rpc_error", message, err);
}
