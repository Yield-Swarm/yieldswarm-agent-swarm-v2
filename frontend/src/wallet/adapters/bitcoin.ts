/**
 * Basic Bitcoin adapter using injected providers that expose the widely adopted
 * UniSat-style API (UniSat, OKX, Magic Eden). Supports connect, native BTC
 * balance, message signing and simple sends. Read fallback uses a public REST
 * API (mempool.space) when the provider lacks a balance method.
 */
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

interface UnisatLikeProvider {
  requestAccounts(): Promise<string[]>;
  getAccounts(): Promise<string[]>;
  getBalance?(): Promise<{ confirmed: number; unconfirmed: number; total: number }>;
  signMessage(message: string, type?: string): Promise<string>;
  sendBitcoin(toAddress: string, satoshis: number, options?: unknown): Promise<string>;
  on?(event: string, handler: (...args: unknown[]) => void): void;
  removeListener?(event: string, handler: (...args: unknown[]) => void): void;
}

interface BtcConnectorDef {
  id: string;
  name: string;
  iconUrl: string;
  downloadUrl: string;
  resolve: () => UnisatLikeProvider | undefined;
}

const CONNECTORS: BtcConnectorDef[] = [
  {
    id: "unisat",
    name: "UniSat",
    iconUrl: "https://next-cdn.unisat.io/_/285/logo/color.svg",
    downloadUrl: "https://unisat.io/download",
    resolve: () => (window as any).unisat as UnisatLikeProvider | undefined,
  },
  {
    id: "okx",
    name: "OKX Wallet",
    iconUrl: "https://www.okx.com/cdn/assets/imgs/239/4A66453B5A0A95FA.png",
    downloadUrl: "https://www.okx.com/web3",
    resolve: () => (window as any).okxwallet?.bitcoin as UnisatLikeProvider | undefined,
  },
  {
    id: "magiceden",
    name: "Magic Eden",
    iconUrl: "https://avatars.githubusercontent.com/u/85590241",
    downloadUrl: "https://wallet.magiceden.io/",
    resolve: () =>
      (window as any).magicEden?.bitcoin?.unisat as UnisatLikeProvider | undefined,
  },
];

const BTC_CHAIN = DEFAULT_CHAIN.bitcoin;

export class BitcoinAdapter implements ChainAdapter {
  readonly namespace = "bitcoin" as const;
  private emitter = new StateEmitter();
  private state: AdapterState;
  private provider?: UnisatLikeProvider;
  private accountsChangedHandler?: (...args: unknown[]) => void;

  constructor() {
    this.state = {
      namespace: "bitcoin",
      status: "disconnected",
      account: null,
      chain: null,
    };
  }

  getConnectors(): WalletConnector[] {
    return CONNECTORS.map((c) => ({
      id: c.id,
      name: c.name,
      namespace: "bitcoin",
      iconUrl: c.iconUrl,
      installed: typeof window !== "undefined" && !!c.resolve(),
      downloadUrl: c.downloadUrl,
    }));
  }

  private bindEvents(provider: UnisatLikeProvider, def: BtcConnectorDef): void {
    if (!provider.on) return;
    this.accountsChangedHandler = (...args: unknown[]) => {
      const accounts = args[0] as string[] | undefined;
      if (accounts && accounts.length) {
        this.setConnected(accounts[0], def.id, def.name);
      } else {
        this.handleDisconnect();
      }
    };
    provider.on("accountsChanged", this.accountsChangedHandler);
  }

  private setConnected(address: string, connectorId: string, name: string): void {
    this.state = {
      namespace: "bitcoin",
      status: "connected",
      chain: getChain(BTC_CHAIN) ?? null,
      account: {
        address,
        namespace: "bitcoin",
        chainId: BTC_CHAIN,
        walletId: connectorId,
        walletName: name,
      },
    };
    this.emitter.emit(this.state);
  }

  private handleDisconnect(): void {
    this.state = {
      namespace: "bitcoin",
      status: "disconnected",
      account: null,
      chain: null,
    };
    this.emitter.emit(this.state);
  }

  async autoConnect(): Promise<WalletAccount | null> {
    const last = session.load("bitcoin");
    if (!last) return null;
    const def = CONNECTORS.find((c) => c.id === last);
    const provider = def?.resolve();
    if (!provider) return null;
    try {
      const accounts = await provider.getAccounts();
      if (accounts.length) {
        this.provider = provider;
        this.bindEvents(provider, def!);
        this.setConnected(accounts[0], last, def!.name);
        return this.state.account;
      }
    } catch {
      session.clear("bitcoin");
    }
    return null;
  }

  async connect(connectorId: string): Promise<WalletAccount> {
    const def = CONNECTORS.find((c) => c.id === connectorId);
    if (!def) throw new WalletError("unsupported", `Unknown Bitcoin wallet: ${connectorId}`);
    const provider = def.resolve();
    if (!provider) throw new WalletError("not_installed", `${def.name} is not installed`);

    this.state = { ...this.state, status: "connecting" };
    this.emitter.emit(this.state);
    try {
      const accounts = await provider.requestAccounts();
      if (!accounts.length) throw new WalletError("rejected", "No Bitcoin account authorized");
      this.provider = provider;
      this.bindEvents(provider, def);
      session.save("bitcoin", connectorId);
      this.setConnected(accounts[0], connectorId, def.name);
      return this.state.account!;
    } catch (err) {
      this.handleDisconnect();
      throw normalizeBtcError(err);
    }
  }

  async disconnect(): Promise<void> {
    session.clear("bitcoin");
    if (this.provider?.removeListener && this.accountsChangedHandler) {
      this.provider.removeListener("accountsChanged", this.accountsChangedHandler);
    }
    this.provider = undefined;
    this.handleDisconnect();
  }

  getState(): AdapterState {
    return this.state;
  }

  async getBalance(token?: string): Promise<TokenBalance> {
    const acct = this.state.account;
    if (!acct) throw new WalletError("not_connected", "Bitcoin wallet not connected");
    if (token) throw new WalletError("unsupported", "BRC-20/Runes balances are not supported");

    let sats = 0n;
    if (this.provider?.getBalance) {
      const bal = await this.provider.getBalance();
      sats = BigInt(bal.total ?? bal.confirmed ?? 0);
    } else {
      sats = await this.fetchBalanceFromApi(acct.address);
    }
    return {
      raw: sats,
      decimals: 8,
      symbol: "BTC",
      formatted: formatBalance(sats, 8),
    };
  }

  private async fetchBalanceFromApi(address: string): Promise<bigint> {
    const url = `${walletConfig.bitcoinApiUrl}/address/${address}`;
    const res = await fetch(url);
    if (!res.ok) throw new WalletError("rpc_error", `bitcoin api ${res.status}`);
    const data = (await res.json()) as {
      chain_stats: { funded_txo_sum: number; spent_txo_sum: number };
    };
    const funded = BigInt(data.chain_stats.funded_txo_sum);
    const spent = BigInt(data.chain_stats.spent_txo_sum);
    return funded - spent;
  }

  async signMessage(message: string): Promise<string> {
    if (!this.provider) throw new WalletError("not_connected", "Bitcoin wallet not connected");
    return this.provider.signMessage(message);
  }

  async sendTransfer(request: TransferRequest): Promise<TransactionResult> {
    const acct = this.state.account;
    if (!acct || !this.provider) {
      throw new WalletError("not_connected", "Bitcoin wallet not connected");
    }
    if (request.token) throw new WalletError("unsupported", "Token sends are not supported");
    try {
      const sats = Number(toBaseUnits(request.amount, 8));
      const txid = await this.provider.sendBitcoin(request.to, sats);
      const chain = getChain(BTC_CHAIN);
      return {
        hash: txid,
        chainId: BTC_CHAIN,
        explorerUrl: chain ? explorerTxUrl(chain, txid) : undefined,
      };
    } catch (err) {
      throw normalizeBtcError(err);
    }
  }

  subscribe(listener: (state: AdapterState) => void): Unsubscribe {
    return this.emitter.subscribe(listener);
  }

  destroy(): void {
    if (this.provider?.removeListener && this.accountsChangedHandler) {
      this.provider.removeListener("accountsChanged", this.accountsChangedHandler);
    }
    this.emitter.clear();
  }
}

function normalizeBtcError(err: unknown): WalletError {
  const message = err instanceof Error ? err.message : String(err);
  if (/reject|cancel|denied/i.test(message)) {
    return new WalletError("rejected", "Request rejected in wallet", err);
  }
  return new WalletError("rpc_error", message, err);
}
