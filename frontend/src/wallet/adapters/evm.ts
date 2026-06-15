/**
 * EVM adapter built on `@wagmi/core` + `viem`. We deliberately use the imperative
 * core actions (not the React hooks) so that wagmi is just an implementation
 * detail behind our unified {@link ChainAdapter} contract, mirroring how
 * RainbowKit sits on top of wagmi but keeping full control of the UX.
 */
import {
  createConfig,
  http,
  connect as wagmiConnect,
  disconnect as wagmiDisconnect,
  getAccount,
  getBalance as wagmiGetBalance,
  reconnect,
  sendTransaction,
  signMessage as wagmiSignMessage,
  switchChain as wagmiSwitchChain,
  watchAccount,
  writeContract,
  type Config,
  type Connector,
  type CreateConnectorFn,
} from "@wagmi/core";
import { arbitrum, base, mainnet, polygon } from "viem/chains";
import { coinbaseWallet, injected, walletConnect } from "@wagmi/connectors";
import { erc20Abi, isAddress, parseUnits } from "viem";

import { walletConfig } from "../config";
import { chainIdFrom, explorerTxUrl, getChain } from "../chains";
import { StateEmitter, session } from "./base";
import {
  WalletError,
  type AdapterState,
  type ChainAdapter,
  type ChainId,
  type TokenBalance,
  type TransactionResult,
  type TransferRequest,
  type Unsubscribe,
  type WalletAccount,
  type WalletConnector,
} from "../types";
import { formatBalance } from "../format";

const WAGMI_CHAINS = [mainnet, polygon, base, arbitrum] as const;

/** Wallet connectors offered to the user, with friendly metadata. */
const CONNECTOR_META: Record<
  string,
  { name: string; iconUrl: string; remote?: boolean; downloadUrl?: string }
> = {
  metaMask: {
    name: "MetaMask",
    iconUrl: "https://raw.githubusercontent.com/MetaMask/brand-resources/master/SVG/SVG_MetaMask_Icon_Color.svg",
    downloadUrl: "https://metamask.io/download/",
  },
  injected: {
    name: "Browser Wallet",
    iconUrl: "https://avatars.githubusercontent.com/u/37784886",
  },
  coinbaseWalletSDK: {
    name: "Coinbase Wallet",
    iconUrl: "https://avatars.githubusercontent.com/u/1885080",
    remote: true,
  },
  walletConnect: {
    name: "WalletConnect",
    iconUrl: "https://avatars.githubusercontent.com/u/37784886",
    remote: true,
  },
};

export class EvmAdapter implements ChainAdapter {
  readonly namespace = "evm" as const;
  private config: Config;
  private emitter = new StateEmitter();
  private state: AdapterState;
  private unwatch?: () => void;
  private connectorsList: readonly Connector[] = [];

  constructor() {
    const connectorFns: CreateConnectorFn[] = [
      injected({ shimDisconnect: true }),
      coinbaseWallet({ appName: walletConfig.appName }),
    ];
    if (walletConfig.walletConnectProjectId) {
      connectorFns.push(
        walletConnect({
          projectId: walletConfig.walletConnectProjectId,
          showQrModal: true,
          metadata: {
            name: walletConfig.appName,
            description: "YieldSwarm unified wallet",
            url: walletConfig.appUrl,
            icons: [],
          },
        }),
      );
    }

    this.config = createConfig({
      chains: WAGMI_CHAINS,
      connectors: connectorFns,
      transports: {
        [mainnet.id]: http(walletConfig.rpc.ethereum),
        [polygon.id]: http(walletConfig.rpc.polygon),
        [base.id]: http(walletConfig.rpc.base),
        [arbitrum.id]: http(walletConfig.rpc.arbitrum),
      },
    });
    this.connectorsList = this.config.connectors;

    this.state = {
      namespace: "evm",
      status: "disconnected",
      account: null,
      chain: null,
    };

    this.unwatch = watchAccount(this.config, {
      onChange: (acct) => this.handleAccountChange(acct),
    });
  }

  private handleAccountChange(acct: ReturnType<typeof getAccount>): void {
    if (acct.status === "connected" && acct.address && acct.chainId) {
      const chainId = chainIdFrom("evm", acct.chainId);
      this.state = {
        namespace: "evm",
        status: "connected",
        chain: getChain(chainId) ?? null,
        account: {
          address: acct.address,
          namespace: "evm",
          chainId,
          walletId: acct.connector?.id ?? "injected",
          walletName: acct.connector?.name ?? "Wallet",
        },
      };
    } else if (acct.status === "reconnecting" || acct.status === "connecting") {
      this.state = { ...this.state, status: "reconnecting" };
    } else {
      this.state = {
        namespace: "evm",
        status: "disconnected",
        account: null,
        chain: null,
      };
    }
    this.emitter.emit(this.state);
  }

  getConnectors(): WalletConnector[] {
    return this.connectorsList.map((c) => {
      const meta = CONNECTOR_META[c.id] ?? CONNECTOR_META.injected;
      return {
        id: c.id,
        name: meta.name ?? c.name,
        namespace: "evm",
        iconUrl: (c.icon as string | undefined) ?? meta.iconUrl,
        installed: meta.remote ? true : typeof window !== "undefined" && !!window.ethereum,
        remote: meta.remote,
        downloadUrl: meta.downloadUrl,
      };
    });
  }

  async autoConnect(): Promise<WalletAccount | null> {
    const last = session.load("evm");
    if (!last) return null;
    try {
      await reconnect(this.config);
      const acct = getAccount(this.config);
      if (acct.status === "connected") {
        this.handleAccountChange(acct);
        return this.state.account;
      }
    } catch {
      session.clear("evm");
    }
    return null;
  }

  async connect(connectorId: string): Promise<WalletAccount> {
    const connector = this.connectorsList.find((c) => c.id === connectorId);
    if (!connector) {
      throw new WalletError("unsupported", `Unknown EVM connector: ${connectorId}`);
    }
    this.state = { ...this.state, status: "connecting" };
    this.emitter.emit(this.state);
    try {
      const result = await wagmiConnect(this.config, { connector });
      const [address] = result.accounts;
      const chainId = chainIdFrom("evm", result.chainId);
      session.save("evm", connectorId);
      this.state = {
        namespace: "evm",
        status: "connected",
        chain: getChain(chainId) ?? null,
        account: {
          address,
          namespace: "evm",
          chainId,
          walletId: connectorId,
          walletName: connector.name,
        },
      };
      this.emitter.emit(this.state);
      return this.state.account!;
    } catch (err) {
      this.state = { ...this.state, status: "disconnected" };
      this.emitter.emit(this.state);
      throw normalizeEvmError(err);
    }
  }

  async disconnect(): Promise<void> {
    session.clear("evm");
    await wagmiDisconnect(this.config);
    this.state = {
      namespace: "evm",
      status: "disconnected",
      account: null,
      chain: null,
    };
    this.emitter.emit(this.state);
  }

  getState(): AdapterState {
    return this.state;
  }

  async getBalance(token?: string): Promise<TokenBalance> {
    const acct = this.state.account;
    if (!acct) throw new WalletError("not_connected", "EVM wallet not connected");
    const chainRef = Number(getChain(acct.chainId)?.reference ?? 1);
    const result = await wagmiGetBalance(this.config, {
      address: acct.address as `0x${string}`,
      chainId: chainRef as 1,
      token: token as `0x${string}` | undefined,
    });
    return {
      raw: result.value,
      decimals: result.decimals,
      symbol: result.symbol,
      formatted: formatBalance(result.value, result.decimals),
      token,
    };
  }

  async signMessage(message: string): Promise<string> {
    const acct = this.state.account;
    if (!acct) throw new WalletError("not_connected", "EVM wallet not connected");
    return wagmiSignMessage(this.config, {
      account: acct.address as `0x${string}`,
      message,
    });
  }

  async sendTransfer(request: TransferRequest): Promise<TransactionResult> {
    const acct = this.state.account;
    if (!acct) throw new WalletError("not_connected", "EVM wallet not connected");
    if (!isAddress(request.to)) {
      throw new WalletError("unknown", `Invalid EVM address: ${request.to}`);
    }
    const chain = getChain(acct.chainId);
    const chainRef = Number(chain?.reference ?? 1);

    try {
      let hash: `0x${string}`;
      if (request.token && isAddress(request.token)) {
        // ERC-20 transfer
        const decimals = request.decimals ?? 18;
        const value = parseUnits(String(request.amount), decimals);
        hash = await writeContract(this.config, {
          abi: erc20Abi,
          address: request.token,
          functionName: "transfer",
          args: [request.to, value],
          chainId: chainRef as 1,
        });
      } else {
        const decimals = chain?.nativeCurrency.decimals ?? 18;
        const value = parseUnits(String(request.amount), decimals);
        hash = await sendTransaction(this.config, {
          to: request.to as `0x${string}`,
          value,
          chainId: chainRef as 1,
        });
      }
      return {
        hash,
        chainId: acct.chainId,
        explorerUrl: chain ? explorerTxUrl(chain, hash) : undefined,
      };
    } catch (err) {
      throw normalizeEvmError(err);
    }
  }

  async switchChain(chainId: ChainId): Promise<void> {
    const chain = getChain(chainId);
    if (!chain || chain.namespace !== "evm") {
      throw new WalletError("unsupported", `Not an EVM chain: ${chainId}`);
    }
    await wagmiSwitchChain(this.config, { chainId: Number(chain.reference) as 1 });
  }

  subscribe(listener: (state: AdapterState) => void): Unsubscribe {
    return this.emitter.subscribe(listener);
  }

  destroy(): void {
    this.unwatch?.();
    this.emitter.clear();
  }
}

function normalizeEvmError(err: unknown): WalletError {
  const message = err instanceof Error ? err.message : String(err);
  if (/rejected|denied|cancel/i.test(message)) {
    return new WalletError("rejected", "Request rejected in wallet", err);
  }
  if (/insufficient funds/i.test(message)) {
    return new WalletError("insufficient_funds", "Insufficient funds", err);
  }
  return new WalletError("rpc_error", message, err);
}
