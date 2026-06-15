/**
 * TON adapter built on `@tonconnect/sdk`. Handles injected (browser extension)
 * and universal-link (mobile) wallets through TonConnect, native TON transfers,
 * and balance reads via the public toncenter RPC.
 */
import TonConnect, {
  isWalletInfoCurrentlyInjected,
  type Wallet,
  type WalletInfo,
} from "@tonconnect/sdk";

import { walletConfig } from "../config";
import { DEFAULT_CHAIN, explorerTxUrl, getChain } from "../chains";
import { StateEmitter } from "./base";
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

const TON_CHAIN = DEFAULT_CHAIN.ton;

export class TonAdapter implements ChainAdapter {
  readonly namespace = "ton" as const;
  private connector: TonConnect;
  private emitter = new StateEmitter();
  private state: AdapterState;
  private wallets: WalletInfo[] = [];
  private unsubscribeStatus?: () => void;

  constructor() {
    this.connector = new TonConnect({ manifestUrl: walletConfig.tonManifestUrl });
    this.state = {
      namespace: "ton",
      status: "disconnected",
      account: null,
      chain: null,
    };
    this.unsubscribeStatus = this.connector.onStatusChange((wallet) => {
      this.handleStatusChange(wallet);
    });
    // Fetch wallet list eagerly so the modal can render install state.
    void this.connector
      .getWallets()
      .then((w) => {
        this.wallets = w;
      })
      .catch(() => undefined);
  }

  private handleStatusChange(wallet: Wallet | null): void {
    if (wallet && wallet.account) {
      this.state = {
        namespace: "ton",
        status: "connected",
        chain: getChain(TON_CHAIN) ?? null,
        account: {
          address: wallet.account.address,
          namespace: "ton",
          chainId: TON_CHAIN,
          walletId: wallet.device.appName,
          walletName: wallet.device.appName,
        },
      };
    } else {
      this.state = {
        namespace: "ton",
        status: "disconnected",
        account: null,
        chain: null,
      };
    }
    this.emitter.emit(this.state);
  }

  getConnectors(): WalletConnector[] {
    return this.wallets.map((w) => ({
      id: w.appName,
      name: w.name,
      namespace: "ton",
      iconUrl: w.imageUrl,
      installed: isWalletInfoCurrentlyInjected(w),
      remote: !isWalletInfoCurrentlyInjected(w),
      downloadUrl: w.aboutUrl,
    }));
  }

  async autoConnect(): Promise<WalletAccount | null> {
    try {
      await this.connector.restoreConnection();
      if (this.connector.connected && this.connector.account) {
        // status change handler already populated state
        return this.state.account;
      }
    } catch {
      /* ignore */
    }
    return null;
  }

  async connect(connectorId: string): Promise<WalletAccount> {
    if (!this.wallets.length) {
      this.wallets = await this.connector.getWallets();
    }
    const wallet = this.wallets.find((w) => w.appName === connectorId);
    if (!wallet) throw new WalletError("unsupported", `Unknown TON wallet: ${connectorId}`);

    this.state = { ...this.state, status: "connecting" };
    this.emitter.emit(this.state);

    return new Promise<WalletAccount>((resolve, reject) => {
      const unsub = this.connector.onStatusChange(
        (w) => {
          if (w && w.account) {
            unsub();
            resolve(this.state.account!);
          }
        },
        (err) => {
          unsub();
          reject(normalizeTonError(err));
        },
      );

      try {
        if (isWalletInfoCurrentlyInjected(wallet)) {
          this.connector.connect({ jsBridgeKey: (wallet as any).jsBridgeKey });
        } else {
          const link = this.connector.connect({
            universalLink: (wallet as any).universalLink,
            bridgeUrl: (wallet as any).bridgeUrl,
          });
          if (typeof link === "string" && typeof window !== "undefined") {
            window.open(link, "_blank", "noopener,noreferrer");
          }
        }
      } catch (err) {
        unsub();
        this.state = { ...this.state, status: "disconnected" };
        this.emitter.emit(this.state);
        reject(normalizeTonError(err));
      }
    });
  }

  async disconnect(): Promise<void> {
    try {
      await this.connector.disconnect();
    } catch {
      /* ignore */
    }
    this.state = {
      namespace: "ton",
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
    if (!acct) throw new WalletError("not_connected", "TON wallet not connected");
    if (token) {
      throw new WalletError("unsupported", "Jetton balances are not supported in this build");
    }
    const url = `https://toncenter.com/api/v2/getAddressBalance?address=${encodeURIComponent(acct.address)}`;
    const res = await fetch(url);
    if (!res.ok) throw new WalletError("rpc_error", `toncenter ${res.status}`);
    const data = (await res.json()) as { ok: boolean; result: string };
    const raw = BigInt(data.result ?? "0");
    return {
      raw,
      decimals: 9,
      symbol: "TON",
      formatted: formatBalance(raw, 9),
    };
  }

  async signMessage(_message: string): Promise<string> {
    // TonConnect signs via ton_proof during connect rather than arbitrary message
    // signing; expose a clear error so callers can fall back appropriately.
    throw new WalletError(
      "unsupported",
      "Arbitrary message signing is not supported by TonConnect; use ton_proof at connect.",
    );
  }

  async sendTransfer(request: TransferRequest): Promise<TransactionResult> {
    const acct = this.state.account;
    if (!acct) throw new WalletError("not_connected", "TON wallet not connected");
    if (request.token) {
      throw new WalletError("unsupported", "Jetton transfers are not supported in this build");
    }
    try {
      const nanotons = toBaseUnits(request.amount, 9).toString();
      const result = await this.connector.sendTransaction({
        validUntil: Math.floor(Date.now() / 1000) + 600,
        messages: [{ address: request.to, amount: nanotons }],
      });
      const chain = getChain(TON_CHAIN);
      // TonConnect returns a signed BOC rather than a tx hash. We surface the
      // BOC as the identifier; consumers can resolve the on-chain hash via an
      // indexer if needed.
      return {
        hash: result.boc,
        chainId: TON_CHAIN,
        explorerUrl: chain ? explorerTxUrl(chain, acct.address) : undefined,
      };
    } catch (err) {
      throw normalizeTonError(err);
    }
  }

  subscribe(listener: (state: AdapterState) => void): Unsubscribe {
    return this.emitter.subscribe(listener);
  }

  destroy(): void {
    this.unsubscribeStatus?.();
    this.emitter.clear();
  }
}

function normalizeTonError(err: unknown): WalletError {
  const message = err instanceof Error ? err.message : String(err);
  if (/reject|cancel|declined/i.test(message)) {
    return new WalletError("rejected", "Request rejected in wallet", err);
  }
  return new WalletError("rpc_error", message, err);
}
