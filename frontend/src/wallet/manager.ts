/**
 * WalletManager — the heart of the unified wallet layer.
 *
 * It owns one {@link ChainAdapter} per ecosystem, multiplexes their events into
 * a single observable snapshot, and exposes one imperative API the whole app
 * uses. Multiple ecosystems can be connected at once (e.g. an EVM wallet for
 * Arena and a Solana wallet for Payments); a single "active" namespace tracks
 * which connection is in focus for balance/transaction defaults.
 */
import { EvmAdapter } from "./adapters/evm";
import { SolanaAdapter } from "./adapters/solana";
import { TonAdapter } from "./adapters/ton";
import { BitcoinAdapter } from "./adapters/bitcoin";
import { getChain } from "./chains";
import {
  WalletError,
  type ChainAdapter,
  type ChainId,
  type ChainInfo,
  type ChainNamespace,
  type TokenBalance,
  type TransactionResult,
  type TransferRequest,
  type Unsubscribe,
  type WalletAccount,
  type WalletConnector,
  type WalletStatus,
} from "./types";

export interface WalletManagerState {
  /** Connected account per ecosystem, when present. */
  accounts: Partial<Record<ChainNamespace, WalletAccount>>;
  /** Connection status per ecosystem. */
  statuses: Record<ChainNamespace, WalletStatus>;
  /** Detected chain per ecosystem. */
  chains: Partial<Record<ChainNamespace, ChainInfo>>;
  /** Ecosystem currently in focus for default balance/tx operations. */
  activeNamespace: ChainNamespace | null;
  activeAccount: WalletAccount | null;
  activeChain: ChainInfo | null;
  /** True while any auto-reconnect attempt is in flight. */
  initializing: boolean;
}

const NAMESPACES: ChainNamespace[] = ["evm", "solana", "ton", "bitcoin"];
const ACTIVE_NS_KEY = "yieldswarm.wallet.active-namespace";

export class WalletManager {
  private adapters: Record<ChainNamespace, ChainAdapter>;
  private listeners = new Set<(s: WalletManagerState) => void>();
  private adapterUnsubs: Unsubscribe[] = [];
  private state: WalletManagerState;

  constructor() {
    this.adapters = {
      evm: new EvmAdapter(),
      solana: new SolanaAdapter(),
      ton: new TonAdapter(),
      bitcoin: new BitcoinAdapter(),
    };

    this.state = {
      accounts: {},
      statuses: { evm: "disconnected", solana: "disconnected", ton: "disconnected", bitcoin: "disconnected" },
      chains: {},
      activeNamespace: this.loadActiveNamespace(),
      activeAccount: null,
      activeChain: null,
      initializing: true,
    };

    for (const ns of NAMESPACES) {
      const unsub = this.adapters[ns].subscribe((adapterState) => {
        this.state = {
          ...this.state,
          accounts: { ...this.state.accounts, [ns]: adapterState.account ?? undefined },
          statuses: { ...this.state.statuses, [ns]: adapterState.status },
          chains: { ...this.state.chains, [ns]: adapterState.chain ?? undefined },
        };
        // Promote a freshly connected ecosystem to active when nothing is active.
        if (adapterState.status === "connected" && !this.state.activeNamespace) {
          this.setActiveNamespace(ns, false);
        }
        // If the active ecosystem disconnected, fall back to any other connection.
        if (this.state.activeNamespace === ns && adapterState.status === "disconnected") {
          const fallback = NAMESPACES.find((n) => this.state.accounts[n]);
          this.setActiveNamespace(fallback ?? null, false);
        }
        this.recomputeActive();
        this.publish();
      });
      this.adapterUnsubs.push(unsub);
    }
  }

  /** Attempt silent reconnection for every ecosystem with a saved session. */
  async init(): Promise<void> {
    await Promise.allSettled(NAMESPACES.map((ns) => this.adapters[ns].autoConnect()));
    this.state = { ...this.state, initializing: false };
    this.recomputeActive();
    this.publish();
  }

  private recomputeActive(): void {
    const ns = this.state.activeNamespace;
    this.state.activeAccount = ns ? this.state.accounts[ns] ?? null : null;
    this.state.activeChain = ns ? this.state.chains[ns] ?? null : null;
  }

  getState(): WalletManagerState {
    return this.state;
  }

  getAdapter(namespace: ChainNamespace): ChainAdapter {
    return this.adapters[namespace];
  }

  /** Every selectable wallet across all ecosystems, for the connect modal. */
  getAllConnectors(): WalletConnector[] {
    return NAMESPACES.flatMap((ns) => this.adapters[ns].getConnectors());
  }

  getConnectors(namespace: ChainNamespace): WalletConnector[] {
    return this.adapters[namespace].getConnectors();
  }

  async connect(namespace: ChainNamespace, connectorId: string): Promise<WalletAccount> {
    const account = await this.adapters[namespace].connect(connectorId);
    this.setActiveNamespace(namespace, true);
    return account;
  }

  async disconnect(namespace?: ChainNamespace): Promise<void> {
    if (namespace) {
      await this.adapters[namespace].disconnect();
      return;
    }
    await Promise.allSettled(NAMESPACES.map((ns) => this.adapters[ns].disconnect()));
  }

  setActiveNamespace(namespace: ChainNamespace | null, publish = true): void {
    this.state = { ...this.state, activeNamespace: namespace };
    this.saveActiveNamespace(namespace);
    this.recomputeActive();
    if (publish) this.publish();
  }

  /** Fetch balance for a namespace (defaults to the active one). */
  async getBalance(
    namespace?: ChainNamespace,
    token?: string,
  ): Promise<TokenBalance> {
    const ns = namespace ?? this.state.activeNamespace;
    if (!ns) throw new WalletError("not_connected", "No active wallet");
    return this.adapters[ns].getBalance(token);
  }

  async signMessage(message: string, namespace?: ChainNamespace): Promise<string> {
    const ns = namespace ?? this.state.activeNamespace;
    if (!ns) throw new WalletError("not_connected", "No active wallet");
    return this.adapters[ns].signMessage(message);
  }

  async sendTransfer(
    request: TransferRequest,
    namespace?: ChainNamespace,
  ): Promise<TransactionResult> {
    const ns = namespace ?? this.state.activeNamespace;
    if (!ns) throw new WalletError("not_connected", "No active wallet");
    return this.adapters[ns].sendTransfer(request);
  }

  async switchChain(chainId: ChainId): Promise<void> {
    const chain = getChain(chainId);
    if (!chain) throw new WalletError("unsupported", `Unknown chain: ${chainId}`);
    const adapter = this.adapters[chain.namespace];
    if (!adapter.switchChain) {
      throw new WalletError("unsupported", `${chain.namespace} cannot switch chains`);
    }
    await adapter.switchChain(chainId);
  }

  subscribe(listener: (state: WalletManagerState) => void): Unsubscribe {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  destroy(): void {
    for (const unsub of this.adapterUnsubs) unsub();
    for (const ns of NAMESPACES) this.adapters[ns].destroy();
    this.listeners.clear();
  }

  private publish(): void {
    const snapshot = { ...this.state };
    for (const l of this.listeners) {
      try {
        l(snapshot);
      } catch (err) {
        console.error("[wallet] manager listener error", err);
      }
    }
  }

  private loadActiveNamespace(): ChainNamespace | null {
    try {
      const v = localStorage.getItem(ACTIVE_NS_KEY) as ChainNamespace | null;
      return v && NAMESPACES.includes(v) ? v : null;
    } catch {
      return null;
    }
  }

  private saveActiveNamespace(ns: ChainNamespace | null): void {
    try {
      if (ns) localStorage.setItem(ACTIVE_NS_KEY, ns);
      else localStorage.removeItem(ACTIVE_NS_KEY);
    } catch {
      /* noop */
    }
  }
}
