import { useState } from "react";

import { useWallet } from "../react/hooks";
import {
  NAMESPACE_LABEL,
  chainsForNamespace,
  explorerAddressUrl,
  getChain,
} from "../chains";
import { shortenAddress } from "../format";
import type { ChainNamespace, WalletAccount } from "../types";
import { BalanceLine } from "./BalanceLine";
import "./wallet.css";

const NAMESPACES: ChainNamespace[] = ["evm", "solana", "ton", "bitcoin"];

/** Modal listing every connected ecosystem with balances and controls. */
export function AccountModal({ onClose }: { onClose: () => void }) {
  const wallet = useWallet();

  return (
    <div
      className="ysw-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Wallet accounts"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="ysw-modal">
        <div className="ysw-modal__header">
          <h2 className="ysw-modal__title">Your wallets</h2>
          <button className="ysw-close" onClick={onClose} aria-label="Close">
            ×
          </button>
        </div>

        <div className="ysw-account-grid">
          {NAMESPACES.map((ns) => {
            const account = wallet.accounts[ns];
            if (!account) return null;
            return (
              <AccountRow
                key={ns}
                account={account}
                isActive={wallet.activeNamespace === ns}
                onActivate={() => wallet.setActiveNamespace(ns)}
                onDisconnect={() => void wallet.disconnect(ns)}
              />
            );
          })}

          {!wallet.isConnected && (
            <div className="ysw-muted" style={{ padding: 16 }}>
              No wallets connected.
            </div>
          )}
        </div>

        <div className="ysw-account-grid" style={{ paddingTop: 0 }}>
          <button
            className="ysw-btn ysw-btn--ghost"
            onClick={() => wallet.openConnectModal()}
          >
            + Connect another wallet
          </button>
          {wallet.isConnected && (
            <button
              className="ysw-btn ysw-btn--ghost"
              onClick={() => {
                void wallet.disconnect();
                onClose();
              }}
            >
              Disconnect all
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function AccountRow({
  account,
  isActive,
  onActivate,
  onDisconnect,
}: {
  account: WalletAccount;
  isActive: boolean;
  onActivate: () => void;
  onDisconnect: () => void;
}) {
  const wallet = useWallet();
  const [switching, setSwitching] = useState(false);
  const chain = getChain(account.chainId);
  const explorer = chain ? explorerAddressUrl(chain, account.address) : undefined;
  const evmChains = account.namespace === "evm" ? chainsForNamespace("evm") : [];

  const handleSwitch = async (chainId: string) => {
    setSwitching(true);
    try {
      await wallet.switchChain(chainId);
    } catch {
      /* user rejected or chain unavailable; state stays unchanged */
    } finally {
      setSwitching(false);
    }
  };

  return (
    <div className={`ysw-account-row ${isActive ? "ysw-account-row--active" : ""}`}>
      <div style={{ display: "flex", gap: 12, alignItems: "center", minWidth: 0 }}>
        {chain?.iconUrl && (
          <img src={chain.iconUrl} alt="" width={28} height={28} style={{ borderRadius: "50%" }} />
        )}
        <div style={{ minWidth: 0 }}>
          <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
            <strong>{NAMESPACE_LABEL[account.namespace]}</strong>
            <span className="ysw-muted">· {account.walletName}</span>
            {isActive && <span className="ysw-chip">Active</span>}
          </div>
          <div className="ysw-mono ysw-muted">
            {explorer ? (
              <a href={explorer} target="_blank" rel="noreferrer" style={{ color: "inherit" }}>
                {shortenAddress(account.address, 6)}
              </a>
            ) : (
              shortenAddress(account.address, 6)
            )}
          </div>
          <BalanceLine namespace={account.namespace} />
          {evmChains.length > 0 && (
            <select
              className="ysw-chip"
              style={{ marginTop: 6 }}
              value={account.chainId}
              disabled={switching}
              onChange={(e) => void handleSwitch(e.target.value)}
            >
              {evmChains.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          )}
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {!isActive && (
          <button
            className="ysw-btn ysw-btn--ghost"
            onClick={onActivate}
            style={{ padding: "6px 10px", fontSize: 12 }}
          >
            Set active
          </button>
        )}
        <button
          className="ysw-btn ysw-btn--ghost"
          onClick={onDisconnect}
          style={{ padding: "6px 10px", fontSize: 12 }}
        >
          Disconnect
        </button>
      </div>
    </div>
  );
}
